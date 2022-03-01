{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE UndecidableInstances #-}

module Database.Redis.Internal.Instances where

import           Control.Monad.Base
import           Control.Monad.Catch
import           Control.Monad.Trans.Control
import           Database.Redis
import           Database.Redis.Core.Internal

instance Exception Reply

deriving instance MonadThrow Redis
deriving instance MonadBase IO Redis
deriving instance MonadBaseControl IO Redis
