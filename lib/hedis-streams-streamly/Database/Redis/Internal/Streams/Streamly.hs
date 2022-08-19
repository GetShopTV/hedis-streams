{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE TypeFamilies #-}

module Database.Redis.Internal.Streams.Streamly where

import Database.Redis

import Database.Redis.Internal.Instances ()
import Database.Redis.Streams.Stream
import Database.Redis.Streams.Types

import Control.Monad.Catch

import GHC.Generics
import Streamly.Data.Unfold (Unfold)
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Prelude (IsStream)
import Streamly.Prelude qualified as Streamly

data StreamKeyReadOptions = StreamKeyReadOptions
    { xReadOpts :: XReadOpts
    , startingMsgID :: MessageID
    }
    deriving (Show, Eq, Generic)

fromStreamStartingFrom ::
    IsStream t => StreamKey -> XReadOpts -> MessageID -> t Redis StreamsRecord
fromStreamStartingFrom key opts = Streamly.unfold (fromStreamUnfold key opts)

fromStreamUnfold :: StreamKey -> XReadOpts -> Unfold Redis MessageID StreamsRecord
fromStreamUnfold key opts =
    Unfold.many
        (Unfold.unfoldrM readStreamProducer)
        Unfold.fromList
  where
    readStreamProducer lstMsgId =
        readStream key lstMsgId opts >>= \case
            Left err -> throwM err -- Possible only when redis sends error message back
            Right (newMsgId, records) -> pure $ Just (records, newMsgId)