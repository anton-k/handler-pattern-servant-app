module Main (main) where

import Data.Proxy
import Servant
import Network.Wai.Handler.Warp (run)

import Control.Exception (try)
import Control.Monad.Except (ExceptT(..))
import qualified Control.Immortal as Immortal
import Control.Concurrent (threadDelay)
import Control.Monad (forever)
import Server
import DI.Log
import App.DI.Db
import App.DI.Log
import App.DI.Setup
import App.DI.Time
import App.State
import Config

import Server.GetMessage qualified as GetMessage
import Server.ListTag    qualified as ListTag
import Server.Save       qualified as Save
import Server.ToggleLog  qualified as ToggleLog

main :: IO ()
main = runServer =<< readConfig

runServer :: Config -> IO ()
runServer config = do
  -- init mutable shared state
  verboseVar <- newVerboseVar

  -- init interfaces (plug in state or interfaces where needed)
  ilog  <- initLog verboseVar
  idb   <- initDb config.db
  itime <- initTime config.time
  let
    isetup = initSetup verboseVar

    -- init local envirnoments
    env =
      Env
        { save =
            let logSave = addLogContext "api.save" ilog
            in  Save.Env logSave (Save.dbLog logSave idb.save) itime

        , getMessage =
            let logGetMessage = addLogContext "api.get-message" ilog
            in  GetMessage.Env (GetMessage.dbLog logGetMessage idb.getMessage) logGetMessage

        , listTag =
            let logListTag = addLogContext "api.list-tag" ilog
            in  ListTag.Env (ListTag.dbLog logListTag idb.listTag) logListTag

        , toggleLogs = ToggleLog.Env (addLogContext "api.toggle-log" ilog) isetup
        }

  runImmortal $ do
    ilog.logInfo $ "Start server on http://localhost:" <> display config.port
    run config.port $ serveWithContextT (Proxy :: Proxy Api) EmptyContext toHandler $ server env

------------------------------------------------------------
-- utils

toHandler :: IO resp -> Servant.Handler resp
toHandler  = Handler . ExceptT . try

runImmortal :: IO () -> IO ()
runImmortal act = do
  -- start an immortal thread
  _thread <- Immortal.create $ \ _thread -> act

  -- in the main thread, sleep until interrupted
  -- (e.g. with Ctrl-C)
  forever $ threadDelay maxBound
