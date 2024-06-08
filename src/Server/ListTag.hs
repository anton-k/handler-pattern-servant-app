-- | Get by tag handler
module Server.ListTag
  ( Env(..)
  , Db(..)
  , handle
  ) where

import DI.Log
import Types

data Env = Env
  { db  :: Db
  , log :: Log
  }

data Db = Db
  { listTag  :: Tag -> IO [Message]
  , validTag :: Tag -> IO Bool
  }

-----------------------------------------
-- Handler

handle :: Env -> Tag -> IO [Message]
handle (Env Db{..} Log{..}) tag = do
  logInfo $ "list tag call: " <> display tag
  listTag tag
