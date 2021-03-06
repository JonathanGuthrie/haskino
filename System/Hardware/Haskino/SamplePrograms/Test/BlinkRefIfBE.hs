-------------------------------------------------------------------------------
-- |
-- Module      :  System.Hardware.Haskino.SamplePrograms.Test.BlinkRefIfBE
--                Based on System.Hardware.Arduino
-- Copyright   :  (c) University of Kansas
-- License     :  BSD3
-- Stability   :  experimental
--
-- The /hello world/ of the arduino world, blinking the led.  This version
-- was written with remote references and demonstrates the IfB expression
-- introduced in version 0.3 of Haskino.
-------------------------------------------------------------------------------

module System.Hardware.Haskino.SamplePrograms.Test.BlinkRefIfBE where

import System.Hardware.Haskino
import Data.Boolean
import Data.Word

blinkOnOff :: RemoteRef Bool -> Expr Word8 -> Expr Word32 -> Arduino ()
blinkOnOff ref led del = do onOff <- readRemoteRef ref
                            digitalWriteE led onOff
                            delayMillisE del
                            modifyRemoteRef ref (\x -> notB x)
                            onOff <- readRemoteRef ref 
                            digitalWriteE led onOff
                            delayMillisE del
                            modifyRemoteRef ref (\x -> notB x)

blinkRefIfBE :: IO ()
blinkRefIfBE = withArduino False "/dev/cu.usbmodem1421" $ do
               let led = 13
               let slow = 2000
               let fast = 1000
               setPinModeE led OUTPUT
               r1 <- newRemoteRef true
               r2 <- newRemoteRef false
               loopE $ do slowFast <- readRemoteRef r2
                          blinkOnOff r1 led (ifB slowFast slow fast)
                          modifyRemoteRef r2 (\x -> notB x)

