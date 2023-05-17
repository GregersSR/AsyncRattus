{-# LANGUAGE TypeOperators, ScopedTypeVariables #-}
{-# OPTIONS -fplugin=AsyncRattus.Plugin #-}
module Main (module Main) where

import AsyncRattus
import AsyncRattus.Stream
import AsyncRattus.Channels
import System.IO.Unsafe
import Control.Concurrent
import Data.Char
import Control.Monad
import Prelude hiding (map, const, zipWith, zip, filter, Left, Right)

-- intInput  :: IO (Box (O Int))
-- intInput = do
--          (inp, cb) <- registerInput
--          let loop = do line <- getLine
--                        when (all isDigit line) $ cb (read line)
--                        loop
--          forkIO loop
--          return inp

-- intOutput  :: O (Str Int) -> IO ()
-- intOutput sig = registerOutput sig print



-- {-# ANN main AsyncRattus #-}
-- main = do ints <- intInput
          
--           let intSig :: O (Str Int)
--               intSig = mkSignal ints
--               newSig :: O (Str Int)
--               newSig = mapAwait (box (+1)) intSig
              
--           intOutput newSig
--           startEventLoop

everySecond :: Box (O ())
everySecond = timer 1000000

{-# ANN numchar NotAsyncRattus #-}

numchar = unsafePerformIO $ do
         putStrLn "register num and char input"
         (intInp :* intCb) <- registerInput
         (charInp :* charCb) <- registerInput
         let loop = do ch <- getChar
                       if isNumber ch then intCb (digitToInt ch)
                         else if ch == '\n' then return ()
                         else charCb ch
                       loop
         forkIO loop
         return (intInp :* charInp)

num  :: Box (O Int)
num = fst' numchar
char  :: Box (O Char) 
char = snd' numchar

{-# ANN module AsyncRattus #-}

numSig :: O (Str Int)
numSig = mkSignal num

charSig :: O (Str Char)
charSig = mkSignal char

sigBoth :: O (Str (Char :* Int))
sigBoth = tl (zipWithAwait (box (:*)) charSig numSig 'a' 0)

sigEither :: O (Str Char)
sigEither = interleave (box (\ x y -> x)) charSig (mapAwait (box intToDigit) numSig)

everySecondSig :: Str ()
everySecondSig = (()::: mkSignal everySecond)

nats :: Str Int
nats = scan (box (\ n _ -> n+1)) 0 everySecondSig

nats' :: Int -> Int -> Str Int
nats' d init = switchS (scan (box (\ n _ -> n + d)) init everySecondSig) (delay (adv (unbox char) `seq` nats' (-d)))



beh :: O (Str Int)
beh = switchAwait numSig (mapO (box (\ _ -> 0 ::: mapAwait (box negate) numSig)) charSig)

{-# ANN main NotAsyncRattus #-}
main = do
  registerOutput sigBoth (\ x -> putStrLn ("sigBoth: " ++ show x))
  registerOutput charSig (\ x -> putStrLn ("charSig: " ++ show x))
  registerOutput numSig (\ x -> putStrLn ("numSig:  " ++ show x))
  registerOutput sigEither (\ x -> putStrLn ("sigEither:  " ++ show x))
  registerOutput beh (\ x -> putStrLn ("beh:  " ++ show x))
  registerOutput (nats' 1 0) (\ x -> putStrLn ("nats:  " ++ show x))
  startEventLoop
  putStrLn "end"
