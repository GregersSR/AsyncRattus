{-# OPTIONS -fplugin=Rattus.Plugin #-}
{-# LANGUAGE TypeOperators #-}

-- | Programming with streams.

module Rattus.Stream
  ( map
  , hd
  , tl
  , const
  , constBox
  , shift
  , shiftMany
  , scan
  , scanMap
  , scanMap2
  , Str(..)
  , zipWith
  , zip
  , unfold
  , filter
  , integral
  )

where

import Rattus
import Prelude hiding (map, const, zipWith, zip, filter)

import Data.VectorSpace

-- | @Str a@ is a stream of values of type @a@.
data Str a = ! a ::: (O (Str a))

-- all functions in this module are in Rattus 
{-# ANN module Rattus #-}

-- | Get the first element (= head) of a stream.
hd :: Str a -> a
hd (x ::: _) = x


-- | Get the tail of a stream, i.e. the remainder after removing the
-- first element.
tl :: Str a -> O (Str a)
tl (_ ::: xs) = xs

-- | Apply a function to each element of a stream.
map :: Box (a -> b) -> Str a -> Str b
{-# NOINLINE [1] map #-}
map f (x ::: xs) = unbox f x ::: delay (map f (adv xs))


-- | Construct a stream that has the same given value at each step.
const :: Stable a => a -> Str a
const a = a ::: delay (const a)

-- | Variant of 'const' that allows any type @a@ as argument as long
-- as it is boxed.
constBox :: Box a -> Str a
constBox a = unbox a ::: delay (constBox a)

-- | Construct a stream by repeatedly applying a function to a given
-- start element. That is, @unfold (box f) x@ will produce the stream
-- @x ::: f x ::: f (f x) ::: ...@
unfold :: Stable a => Box (a -> a) -> a -> Str a
unfold f x = x ::: delay (unfold f (unbox f x))

-- | Similar to Haskell's 'scanl'.
--
-- > scan (box f) x (v1 ::: v2 ::: v3 ::: ... ) == (x `f` v1) ::: ((x `f` v1) `f` v2) ::: ...
--
-- Note: Unlike 'scanl', 'scan' starts with @x `f` v1@, not @x@.
{-# NOINLINE [1] scan #-}
scan :: (Stable b) => Box(b -> a -> b) -> b -> Str a -> Str b
scan f acc (a ::: as) =  acc' ::: delay (scan f acc' (adv as))
  where acc' = unbox f acc a

-- | 'scanMap' is a composition of 'map' and 'scan':
--
-- > scanMap f g x === map g . scan f x
{-# NOINLINE [1] scanMap #-}
scanMap :: (Stable b) => Box(b -> a -> b) -> Box (b -> c) -> b -> Str a -> Str c
scanMap f p acc (a ::: as) =  unbox p acc' ::: delay (scanMap f p acc' (adv as))
  where acc' = unbox f acc a


-- | 'scanMap2' is similar to 'scanMap' but takes two input streams.
scanMap2 :: (Stable b) => Box(b -> a1 -> a2 -> b) -> Box (b -> c) -> b -> Str a1 -> Str a2 -> Str c
scanMap2 f p acc (a1 ::: as1) (a2 ::: as2) =
    unbox p acc' ::: delay (scanMap2 f p acc' (adv as1) (adv as2))
  where acc' = unbox f acc a1 a2

-- | Similar to 'Prelude.zipWith' on Haskell lists.
zipWith :: Box(a -> b -> c) -> Str a -> Str b -> Str c
zipWith f (a ::: as) (b ::: bs) = unbox f a b ::: delay (zipWith f (adv as) (adv bs))

-- | Similar to 'Prelude.zip' on Haskell lists.
{-# NOINLINE [1] zip #-}
zip :: Str a -> Str b -> Str (a:*b)
zip (a ::: as) (b ::: bs) =  (a :* b) ::: delay (zip (adv as) (adv bs))


-- | Filter out elements from a stream according to a predicate.
filter :: Box(a -> Bool) -> Str a -> Str(Maybe' a)
filter p = map (box (\a -> if unbox p a then Just' a else Nothing'))

{-| Given a value a and a stream as, this function produces a stream
  that behaves like -}
shift :: Stable a => a -> Str a -> Str a
shift a (x ::: xs) = a ::: delay (shift x (adv xs))


{-| Given a list @[a1, ..., an]@ of elements and a stream @xs@ this
  function constructs a stream that starts with the elements @a1, ...,
  an@, and then proceeds as @xs@. In particular, this means that the
  ith element of the original stream @xs@ is the (i+n)th element of
  the new stream. In other words @shiftMany@ behaves like repeatedly
  applying @shift@ for each element in the list. -}
shiftMany :: Stable a => List a -> Str a -> Str a
shiftMany l xs = run l Nil xs where
  run :: Stable a => List a -> List a -> Str a -> Str a
  run (b :! bs) buf (x ::: xs) = b ::: delay (run bs (x :! buf) (adv xs))
  run Nil buf (x ::: xs) =
    case reverse' buf of
      b :! bs -> b ::: delay (run bs (x :! Nil) (adv xs))
      Nil -> x ::: xs
    
-- | Calculates an approximation of an integral of the stream of type
-- @Str a@ (the y-axis), where the stream of type @Str s@ provides the
-- distance between measurements (i.e. the distance along the y axis).
integral :: (Stable a, VectorSpace a s) => a -> Str s -> Str a -> Str a
integral acc (t ::: ts) (a ::: as) = acc' ::: delay (integral acc' (adv ts) (adv as))
  where acc' = acc ^+^ (t *^ a)



{-# RULES
  "map/map" forall f g xs.
    map f (map g xs) = map (box (unbox f . unbox g)) xs ;

  "map/scan" forall (f :: Box(b -> a -> b)) (p :: Box (b -> c)) (acc :: b) (as :: Str a).
    map p (scan f acc as) = scanMap f p acc as ;

  "scan/scan" forall f g b c as.
    scan g c (scan f b as) =
      let f' = unbox f; g' = unbox g in
      scanMap (box (\ (b:*c) a -> let b' = f' b a in (b':* g' c b'))) (box snd') (b:*c) as ;

  "scan/scanMap" forall f g p b c as.
    scan g c (scanMap f p b as) =
      let f' = unbox f; g' = unbox g; p' = unbox p in
      scanMap (box (\ (b:*c) a -> let b' = f' (p' b) a in (b':* g' c b'))) (box snd') (b:*c) as ;

  "zip/map" forall xs ys f.
    map f (zip xs ys) = let f' = unbox f in zipWith (box (\ x y -> f' (x :* y))) xs ys
#-}
