{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeFamilies #-}

module Database.Redis.Internal.Streams.Streamly where

import Database.Redis

import Database.Redis.Internal.Instances ()
import Database.Redis.Streams.Stream
import Database.Redis.Streams.Types

import GHC.Generics

import Streamly.Data.Stream.Prelude as Stream
import Streamly.Data.Unfold (Unfold)
import Streamly.Data.Unfold qualified as Unfold

data StreamKeyReadOptions = StreamKeyReadOptions
    { xReadOpts :: XReadOpts
    , startingMsgID :: MessageID
    }
    deriving (Show, Eq, Generic)

fromStreamStartingFrom ::
    StreamKey -> XReadOpts -> MessageID -> Stream Redis StreamsRecord
fromStreamStartingFrom key opts = Stream.unfold (fromStreamUnfold key opts)

fromStreamUnfold :: StreamKey -> XReadOpts -> Unfold Redis MessageID StreamsRecord
fromStreamUnfold key opts =
    Unfold.many
        Unfold.fromList
        (Unfold.unfoldrM readStreamProducer)
  where
    readStreamProducer lstMsgId =
        readStream key lstMsgId opts >>= \case
            Left _err -> readStreamProducer lstMsgId -- Possible only when redis sends error message back
            Right (newMsgId, records) -> pure $ Just (records, newMsgId)