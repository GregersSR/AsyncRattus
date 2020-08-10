{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE CPP #-}


-- | This module implements a constraint solver plugin for the
-- 'Stable' type class.

module Rattus.Plugin.StableSolver (tcStable) where

import Rattus.Plugin.Utils

import Prelude hiding ((<>))
import GhcPlugins
  (Type, Var, CommandLineOption,tyConSingleDataCon,
   mkCoreConApps,getTyVar_maybe)
import CoreSyn
import TcEvidence
import Class

#if __GLASGOW_HASKELL__ >= 810
import Constraint
#endif

import Data.Set (Set)
import qualified Data.Set as Set


import TcRnTypes


-- | Constraint solver plugin for the 'Stable' type class.
tcStable :: [CommandLineOption] -> Maybe TcPlugin
tcStable _ = Just $ TcPlugin
  { tcPluginInit = return ()
  , tcPluginSolve = \ () -> stableSolver
  , tcPluginStop = \ () -> return ()
  }


wrap :: Class -> Type -> EvTerm
wrap cls ty = EvExpr appDc
  where
    tyCon = classTyCon cls
    dc = tyConSingleDataCon tyCon
    appDc = mkCoreConApps dc [Type ty]

solveStable :: Set Var -> (Type, (Ct,Class)) -> Maybe (EvTerm, Ct)
solveStable c (ty,(ct,cl))
  | isStable c ty = Just (wrap cl ty, ct)
  | otherwise = Nothing

stableSolver :: [Ct] -> [Ct] -> [Ct] -> TcPluginM TcPluginResult
stableSolver given _derived wanted = do
  let chSt = concatMap filterCt wanted
  let haveSt = Set.fromList $ concatMap (filterTypeVar . fst) $ concatMap filterCt given
  case mapM (solveStable haveSt) chSt of
    Just evs -> return $ TcPluginOk evs []
    Nothing -> return $ TcPluginOk [] []

  where filterCt ct@(CDictCan {cc_class = cl, cc_tyargs = [ty]})
          = case getNameModule cl of
              Just (name,mod)
                | isRattModule mod && name == "Stable" -> [(ty,(ct,cl))]
              _ -> []
        filterCt _ = []
        filterTypeVar ty = case getTyVar_maybe ty of
          Just v -> [v]
          Nothing -> []
