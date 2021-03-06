{-# LANGUAGE OverloadedStrings #-}
module Language.Haskell.ASBrowser.Integration.CabalTest where

import Control.Applicative ((<$>))

import Language.Haskell.ASBrowser.Integration.Cabal
import Language.Haskell.ASBrowser.Database
import Language.Haskell.ASBrowser.Types
import Language.Haskell.ASBrowser.TestHarness
import Language.Haskell.ASBrowser.Operations.Packages

import Data.Acid
import Test.Tasty
import Test.Tasty.HUnit
import Data.Maybe
import Data.IxSet.Typed
import Control.Monad

cabalTests :: TestTree
cabalTests = testGroup "Cabal Tests"
  [  testCase "updateFromCabal" $
      withTestAcid $ \acid -> do
        updateFromCabal acid
        let pkgAcid=PackageKey "acid-state" "0.12.3" Packaged
        mpkg1 <- query acid $ GetPackage pkgAcid
        isJust mpkg1 @? "acid-state 0.12.3 not found"
        let url = pkgDocURL $ fromJust mpkg1
        url @?= (Just $ URL "http://hackage.haskell.org/package/acid-state-0.12.3")

        mpkg2 <- query acid $ GetLatest "acid-state"
        isJust mpkg2 @? "acid-state latest not found"

        cpnts0 <- query acid $ ListComponents $ pkgKey $ fromJust mpkg1
        assertEqual "components for old version" 0 (size cpnts0)
        ensurePackageModules (pkgKey $ fromJust mpkg1) acid
        cpnts <- query acid $ ListComponents $ pkgKey $ fromJust mpkg1
        assertEqual "no components" 1 (size cpnts)
        cName (cKey $ head $ toList cpnts) @?= ""

        mods <- query acid $ ListModules (pkgKey $ fromJust mpkg1) (Just "")
        size mods > 0 @? "no modules for acid-state library"
        let dam = filter (("Data.Acid" ==) . modName . modKey) $ toList mods
        assertEqual "not 1 Data.Acid module" 1 (length dam)
        let testMod = head dam
        modComponents testMod @?= [ModuleInclusion "" Exposed Nothing]
        modURLs testMod @?= URLs (Just $ URL "http://hackage.haskell.org/package/acid-state-0.12.3/docs/src/Data-Acid.html")  (Just $ URL "http://hackage.haskell.org/package/acid-state-0.12.3/docs/Data-Acid.html")

        decls1 <- query acid $ ListDecls (modKey testMod)
        assertEqual "decls are present" 0 (length decls1)
        ensurePackageDecls (modPackageKey $ modKey testMod) acid
        decls2 <- query acid $ ListDecls (modKey testMod)
        (length decls2)>0 @? "decls are not present"

        allPkgs <- liftM onlyLastVersions $ query acid $ ListByLocal Packaged
        let l=length allPkgs
        l >= 7793 && l < 9000 @? "wrong number of packages: " ++ show l
  ]
