{-# LANGUAGE TemplateHaskell #-}
module System.Hardware.Haskino.ShallowDeepPlugin (plugin) where

import CoreMonad
import GhcPlugins
import HscTypes
import Outputable
import SimplEnv
import SimplUtils
import Data.Data
import Data.Typeable
import DataCon
import IOEnv 
import OccName
import TysPrim
import Unique
import Var
import Control.Monad
import Control.Monad.Writer
import Data.List 

import qualified System.Hardware.Haskino

plugin :: Plugin
plugin = defaultPlugin {
  installCoreToDos = install
}

install :: [CommandLineOption] -> [CoreToDo] -> CoreM [CoreToDo]
install _ todo = do
  reinitializeGlobals
  let repLambdaToDo = [CoreDoPluginPass "RepLambda" repLambdaPass]
  let condToDo = [CoreDoPluginPass "RepLambda" condPass]
  let dumpTodo = [CoreDoPluginPass "DumpPass" dumpPass]
  return $ condToDo ++ [rules0Pass] ++ repLambdaToDo ++ [rules1Pass] ++ todo -- ++ dumpTodo

rules0Pass :: CoreToDo
rules0Pass = CoreDoSimplify 1 SimplMode {
            sm_names = [],
            sm_phase = Phase 0,
            sm_rules = True,
            sm_inline = True,
            sm_case_case = False,
            sm_eta_expand = False
            }

rules1Pass :: CoreToDo
rules1Pass = CoreDoSimplify 1 SimplMode {
            sm_names = [],
            sm_phase = Phase 1,
            sm_rules = True,
            sm_inline = True,
            sm_case_case = False,
            sm_eta_expand = False
            }

repLambdaPass :: ModGuts -> CoreM ModGuts
repLambdaPass guts = bindsOnlyPass (mapM repBind) guts

condPass :: ModGuts -> CoreM ModGuts
condPass guts = do
  Just ifThenElseName <- thNameToGhcName 'System.Hardware.Haskino.ifThenElse
  ifThenElseId <- lookupId ifThenElseName
  bindsOnlyPass (mapM (condBind ifThenElseId)) guts

dumpPass :: ModGuts -> CoreM ModGuts
dumpPass guts = do
  putMsgS "In dumpPass"
  putMsg $ ppr (mg_binds guts)
  return guts      

repBind :: CoreBind -> CoreM CoreBind
repBind bndr@(NonRec b e) = do
  e' <- repExpr e
  return (NonRec b e')
repBind (Rec bs) = do
  bs' <- repBind' bs
  return $ Rec bs'

repBind' :: [(Id, CoreExpr)] -> CoreM [(Id, CoreExpr)]
repBind' [] = return []
repBind' ((b, e) : bs) = do
  e' <- repExpr e
  bs' <- repBind' bs
  return $ (b, e') : bs'

repExpr :: CoreExpr -> CoreM CoreExpr
repExpr e = 
  case e of
    Var v -> return $ Var v
    Lit l -> return $ Lit l
    Type ty -> return $ Type ty
    Coercion co -> return $ Coercion co
    App (App (App (App (App (Var f) (Type _)) (Type _)) (Type t3)) (Lam b bd)) (App (Var f2) (Type t4)) | 
      varString f == "." && varString f2 == "rep_" -> do
      bd' <- repExpr bd
      newb <- buildId ((varString b) ++ "_rep") t3
      bd'' <- subVarExpr b (App (App (Var f2) (Type t4)) (Var newb)) bd'
      return $ Lam newb bd''
      -- The below was the initial attempt to insert a let inside the lambda
      -- The thought was the the simplifier would do the substitution from the
      -- let to the variable occurance.  However, this only happened in the
      -- inner bind, and did not work across the inner lambda for the outer
      -- bind.  Therefore, the above was used instead, to do the substitution
      -- as part of the pass.
      --
      -- let newe = Lam newb (Let (NonRec b (App (App (Var f2) (Type t4)) (Var newb))) bd')
      -- return newe
    App e1 e2 -> do
      e1' <- repExpr e1
      e2' <- repExpr e2
      return $ App e1' e2'
    Lam tb e -> do
      e' <- repExpr e
      return $ Lam tb e'
    Let bind body -> do
      body' <- repExpr body
      bind' <- case bind of 
                  (NonRec v e) -> do
                    e' <- repExpr e
                    return $ NonRec v e'
                  (Rec rbs) -> do
                    rbs' <- repBind' rbs
                    return $ Rec rbs'
      return $ Let bind' body' 
    Case e tb ty alts -> do
      e' <- repExpr e
      alts' <- procRepAlts alts
      return $ Case e' tb ty alts'
    Tick t e -> do
      e' <- repExpr e
      return $ Tick t e'
    Cast e co -> do
      e' <- repExpr e
      return $ Cast e' co

varString :: Id -> String 
varString = occNameString . nameOccName . Var.varName

nameString :: Name -> String 
nameString = occNameString . nameOccName

buildId :: String -> Type -> CoreM Id
buildId varName typ = do
  dunique <- getUniqueM
  let name = mkInternalName dunique (mkOccName OccName.varName varName) noSrcSpan
  return $ mkLocalVar VanillaId name typ vanillaIdInfo

procRepAlts :: [GhcPlugins.Alt CoreBndr] -> CoreM [GhcPlugins.Alt CoreBndr]
procRepAlts [] = return []
procRepAlts ((ac, b, a) : as) = do
  a' <- repExpr a
  bs' <- procRepAlts as
  return $ (ac, b, a') : bs'

subVarExpr :: Id -> CoreExpr -> CoreExpr -> CoreM CoreExpr
subVarExpr id esub e = 
  case e of
    Var v -> do
      if v == id
      then return esub
      else return $ Var v
    Lit l -> return $ Lit l
    Type ty -> return $ Type ty
    Coercion co -> return $ Coercion co
    App e1 e2 -> do
      e1' <- subVarExpr id esub e1
      e2' <- subVarExpr id esub e2
      return $ App e1' e2'
    Lam tb e -> do
      e' <- subVarExpr id esub e
      return $ Lam tb e'
    Let bind body -> do
      body' <- subVarExpr id esub body
      bind' <- case bind of 
                  (NonRec v e) -> do
                    e' <- subVarExpr id esub e
                    return $ NonRec v e'
                  (Rec rbs) -> do
                    rbs' <- subVarExpr' id esub rbs
                    return $ Rec rbs'
      return $ Let bind' body' 
    Case e tb ty alts -> do
      e' <- subVarExpr id esub e
      alts' <- subVarExprAlts id esub alts
      return $ Case e' tb ty alts'
    Tick t e -> do
      e' <- subVarExpr id esub e
      return $ Tick t e'
    Cast e co -> do
      e' <- subVarExpr id esub e
      return $ Cast e' co

subVarExpr' :: Id -> CoreExpr -> [(Id, CoreExpr)] -> CoreM [(Id, CoreExpr)]
subVarExpr' _ _ [] = return []
subVarExpr' id esub ((b, e) : bs) = do
  e' <- subVarExpr id esub e
  bs' <- subVarExpr' id esub bs
  return $ (b, e') : bs'

subVarExprAlts :: Id -> CoreExpr -> [GhcPlugins.Alt CoreBndr] -> CoreM [GhcPlugins.Alt CoreBndr]
subVarExprAlts _ _ [] = return []
subVarExprAlts id esub ((ac, b, a) : as) = do
  a' <- subVarExpr id esub a
  bs' <- subVarExprAlts id esub as
  return $ (ac, b, a') : bs'

condBind :: Id -> CoreBind -> CoreM CoreBind
condBind ifid bndr@(NonRec b e) = do
  e' <- condExpr ifid e
  return (NonRec b e')
condBind ifid (Rec bs) = do
  bs' <- condExpr' ifid bs
  return $ Rec bs'

condBind' :: Id -> [(Id, CoreExpr)] -> CoreM [(Id, CoreExpr)]
condBind' _ [] = return []
condBind' ifid ((b, e) : bs) = do
  e' <- condExpr ifid e
  bs' <- condBind' ifid bs
  return $ (b, e') : bs'

condExpr :: Id -> CoreExpr -> CoreM CoreExpr
condExpr ifid e = do
  case e of
    Var v -> return $ Var v
    Lit l -> return $ Lit l
    Type ty -> return $ Type ty
    Coercion co -> return $ Coercion co
    App e1 e2 -> do
      e1' <- condExpr ifid e1
      e2' <- condExpr ifid e2
      return $ App e1' e2'
    Lam tb e -> do
      e' <- condExpr ifid e
      return $ Lam tb e'
    Let bind body -> do
      body' <- condExpr ifid body
      bind' <- case bind of 
                  (NonRec v e) -> do
                    e' <- condExpr ifid e
                    return $ NonRec v e'
                  (Rec rbs) -> do
                    rbs' <- condExpr' ifid rbs
                    return $ Rec rbs'
      return $ Let bind' body' 
{-
    Case e tb ty alts | show (typeOf ty) == "Arduino ()" -> do
      e' <- condExpr ifid e
      alts' <- condExprAlts ifid alts
      if nameString (getName (exprType e)) == "Bool"
      then condTransform ifid e' alts'
      else return $ Case e' tb ty alts'
-}
    Case e tb ty alts | show (typeOf ty) == "Arduino ()" -> do
      e' <- condExpr ifid e
      alts' <- condExprAlts ifid alts
      if length alts' == 2 
      then case alts' of
        [(ac1, _, _), _] -> do
          case ac1 of 
            DataAlt d -> do
              if nameString (getName d) == "False"
              then condTransform ifid e' alts'
              else return $ Case e' tb ty alts'
            _ -> return $ Case e' tb ty alts'
      else return $ Case e' tb ty alts'
    Case e tb ty alts -> do
      e' <- condExpr ifid e
      alts' <- condExprAlts ifid alts
      return $ Case e' tb ty alts'
    Tick t e -> do
      e' <- condExpr ifid e
      return $ Tick t e'
    Cast e co -> do
      e' <- condExpr ifid e
      return $ Cast e' co

condExpr' :: Id -> [(Id, CoreExpr)] -> CoreM [(Id, CoreExpr)]
condExpr' _ [] = return []
condExpr' ifid ((b, e) : bs) = do
  e' <- condExpr ifid e
  bs' <- condExpr' ifid bs
  return $ (b, e') : bs'

condExprAlts :: Id -> [GhcPlugins.Alt CoreBndr] -> CoreM [GhcPlugins.Alt CoreBndr]
condExprAlts _ [] = return []
condExprAlts ifid ((ac, b, a) : as) = do
  a' <- condExpr ifid a
  bs' <- condExprAlts ifid as
  return $ (ac, b, a') : bs'

condTransform :: Id -> CoreExpr -> [GhcPlugins.Alt CoreBndr] -> CoreM CoreExpr
condTransform ifid e alts = do
  case alts of
    [(_, _, e1),(_, _, e2)] -> do
      return $ mkCoreApps (Var ifid) [e, e1, e2]
      -- App (App (App (Var ifid) e) e1) e2
