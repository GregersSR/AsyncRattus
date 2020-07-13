{-# LANGUAGE TypeOperators #-}
module Main (module Main) where

import Rattus
import Rattus.Stream
import Rattus.ToHaskell

import qualified Prelude
import Prelude hiding ((<*>), map)

-- If we make pairs stable, we get a memory leak:
-- cannot do this anymore. We dissallow user-supplied Stable instances
-- instance (Stable a, Stable b) => Stable (a,b)


type Lazy a = ((),a)

{-# ANN module Rattus #-}


lazyAdd :: (a, Int) -> ((), Int) -> ((), Int)
lazyAdd = (\ (_,x) y -> fmap (+x) y )


scan3 :: (Stable a) => Box(a -> a -> a) -> Box (a -> Bool) -> a -> Str a -> Str a
scan3 f p acc (a ::: as) =  (if unbox p a then acc else a)
      ::: (delay (scan3 f p acc') <*> as)
  where acc' = unbox f acc a


-- Unless the strictification transformation is applied this function
-- will leak memory.
test1 :: Int -> Str (Int) -> Str (Int)
test1 = scan3 (box (+)) (box (== 0))



-- Unless the strictification transformation is applied this function
-- will leak memory. In addition, since it uses a lazy data structure,
-- it would also leak memory unless progres/promote evaluate to normal
-- form (using deepseq).
-- test2 :: Lazy Int -> Str (Lazy Int) -> Str (Lazy Int)
-- test2 = scan3 (box lazyAdd) (box (\ (_,x) -> x == 0))

-- If we Haskell's pair types, we get a memory leak:

leaky :: Str (Lazy Int) -> Str (Lazy Int)
leaky ((_,x):::xs) = ((),1) ::: delay (leaky  (fmap ((+) x) (hd (adv xs)) ::: (tl (adv xs))))


type Strict a = (():*a)

leakyStrict :: Str (Strict Int) -> Str (Strict Int)
leakyStrict ((_:*x):::xs) = (():*11) ::: delay (leakyStrict  (fmap ((+) x) (hd (adv xs)) ::: (tl (adv xs))))


buffer :: Stable a => Str a -> Str (List a)
buffer = scan (box (flip (:!))) Nil


{-# ANN recurse NotRattus #-}
recurse 0 (x : _) = print x
recurse n (_ : xs) = recurse (n-1) xs
recurse _ [] = putStrLn "the impossible happened: stream terminated"

{-# ANN main NotRattus #-}
main = do  
  let x =  fromStr $ test1 1 (toStr [1..])
  recurse 10000000 x
  
  let x = fromStr $ leakyStrict  (toStr $ Prelude.map (\ x-> (():*x)) [1..])
  recurse 10000000 x


  let x = fromStr $ leaky (toStr $ Prelude.map (\ x-> ((),x)) [1..])
  recurse 10000000 x
  
--   -- for comparison the Haskell code below does leak
--   let x = scan2 (+) (1::Int) [1,1..]
--   recurse 10000000 x

-- {-# ANN scan2 NotRattus #-}
-- scan2 :: (Int -> Int -> Int) -> Int -> [Int] -> [Int]
-- scan2 f acc (a : as) =  (if a == 0 then acc else 0) : scan2 f (f acc a) as
