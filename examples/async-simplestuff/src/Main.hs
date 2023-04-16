module Main where

import StandardLibrary
import Rattus.ToHaskell
import Rattus.Primitives
import Graphics.Gloss.Interface.Pure.Game
import Rattus.Stream
import Debug.Trace as D
import qualified Data.Set as Set
import Simple

type World = (Maybe InputValue, String, O(Str String))

initial' :: World
initial' = (Nothing, "", textStr (accumulatorStr kbStr) resetStr)

render' :: World -> Picture
render' (_, text, _) = Translate (-(fromIntegral sizex)/2.0) 0 (Text text)

handleEvent' :: Event -> World -> World
handleEvent' (EventKey (Char c) Down _ _) (_, text, str) = (Just (1, CharValue c), trace ("This is the text now:" ++ text) text, str)
handleEvent' (EventKey (SpecialKey KeyF1) Down _ _) (_, text, str) = (Just (2, BoolValue True), trace ("This is a reset:" ++ text) text, str)
handleEvent' e world = trace ("nothing interesting happend: " ++ show e) world

step' :: Float -> World -> World
step' _ (Just input, _, laterStr) = (Nothing, a, as)
    where (a ::: as) =  adv' laterStr input 
step' _ world = world


-- Sizes
sizex = 1512 
sizey = 982 

main :: IO ()
main = do
    print "THIS IS BEFORE"
    let a = addOne (Delay (Set.singleton 1) (\(1, IntValue i) -> D.trace ("LATER RETURNING: " ++ show i) i))
    print "THIS IS AFTER A IS DEFINED"
    let i = adv' a (1, IntValue 400)
    print i

    print "THIS IS BEFORE Q P"
    let q = Delay (Set.singleton 3) (\(3, IntValue i) -> D.trace ("Q LATER RETURNING: " ++ show i) i)
    let p = Delay (Set.singleton 4) (\(4, IntValue i) -> D.trace ("P LATER RETURNING: " ++ show i) i)

    let y = Delay (Set.singleton 5) (\(5, IntValue i) -> D.trace ("P LATER RETURNING: " ++ show i) i)
    
    print "THIS IS BEFORE S"
    let s = describe q p
    let z = describe q q

    print "TRY TO ADV S ON CHANEL 3"
    let k = adv' s (3, IntValue 300)
    print "TRY TO ADV S ON CHANEL 4"
    let j = adv' s (4, IntValue 400)
    print "RESULTS"
    print j
    print "AFTER J"
    print k

    print "BOTH"
    let o = adv' z (3, IntValue 3)
    print o

    print "Naive"
    let n = naiveIf False (Delay (Set.singleton 1) (\(1, IntValue i) -> i + 1)) (Delay (Set.singleton 2) (\(2, IntValue i) -> i + 2))
    let l = adv' n (2, IntValue 1)
    print l


{-
main = play
       (InWindow "text writer 9000" (sizex, sizey) (0,0))
       white
       10
       initial'
       render'
       handleEvent'
       step'
-}