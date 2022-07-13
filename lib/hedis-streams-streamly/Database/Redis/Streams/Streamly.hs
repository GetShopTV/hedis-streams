module Database.Redis.Streams.Streamly where

import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as Ch8

import Database.Redis
import Database.Redis qualified as Redis

import Database.Redis.Internal.Instances ()
import Database.Redis.Streams.Stream
import Database.Redis.Streams.Types.Stream

import Control.Monad.Catch
import Control.Monad.IO.Class

import Database.Redis.Streams.SpecialMessageID
import Streamly.Data.Unfold (Unfold)
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Prelude (IsStream)
import Streamly.Prelude qualified as Streamly

fromStream :: IsStream t => StreamKey -> XReadOpts -> t Redis StreamsRecord
fromStream key opts = fromStreamStartingFrom key opts newestMessageID

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

sendStream ::
    IsStream t =>
    StreamKey ->
    t Redis Entry ->
    t Redis MessageID
sendStream streamOut = Streamly.mapM sendStep
  where
    sendStep entry =
        sendUpstream streamOut entry >>= \case
            Left err -> throwM err -- Possible only when redis sends error message back
            Right msgId -> pure $ MessageID msgId