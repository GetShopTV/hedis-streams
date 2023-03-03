{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Database.Redis.Internal.Instances where

import Control.Monad.Base
import Control.Monad.Catch
import Control.Monad.Trans.Control
import Database.Redis
import Database.Redis.Core.Internal

deriving newtype instance MonadThrow Redis
deriving newtype instance MonadBase IO Redis
deriving newtype instance MonadBaseControl IO Redis
