{-# OPTIONS -fplugin=Rattus.Plugin #-}


-- | The bare-bones Rattus language. To program with streams and
-- events import "Rattus.Stream" and "Rattus.Events"; to program with
-- Yampa-style signal functions import "Rattus.Yampa".

module Rattus (
  module Rattus.Primitives,
  module Rattus.Strict,
  Rattus(..),
  (|*|),
  (|**),
  (<*>),
  (<**))
  where

import Rattus.Plugin
import Rattus.Strict
import Rattus.Primitives


import Prelude hiding ((<*>))

-- all functions in this module are in Rattus 
{-# ANN module Rattus #-}


-- | Applicative operator for 'O'.
(<*>) :: O (a -> b) -> O a -> O b
f <*> x = delay (adv f (adv x))

-- | Variant of '(<*>)' where the argument is of a stable type..
(<**) :: Stable a => O (a -> b) -> a -> O b
f <** x = delay (adv f x)

-- | Applicative operator for 'Box'.
(|*|) :: Box (a -> b) -> Box a -> Box b
f |*| x = box (unbox f (unbox x))

-- | Variant of '(|*|)' where the argument is of a stable type..
(|**) :: Stable a => Box (a -> b) -> a -> Box b
f |** x = box (unbox f x)
