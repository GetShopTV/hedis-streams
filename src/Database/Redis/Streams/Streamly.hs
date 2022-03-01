module Database.Redis.Streams.Streamly
    ( readStream
    , readStreamStartingFrom
    , readStartingFromUnfold
    , sendStream
    ) where

import           Data.ByteString                ( ByteString )
import qualified Data.ByteString.Char8         as Ch8

import           Database.Redis
import qualified Database.Redis                as Redis
import           Database.Redis.Internal.Instances
                                                ( )
import           Database.Redis.Streams

import           Control.Exception
import           Control.Monad.Catch
import           Control.Monad.IO.Class
import qualified Streamly.Data.Fold            as Fold
import           Streamly.Data.Fold             ( Fold )
import qualified Streamly.Data.Unfold          as Unfold
import           Streamly.Data.Unfold           ( Unfold )
import qualified Streamly.Prelude              as Streamly
import           Streamly.Prelude               ( IsStream
                                                , MonadAsync
                                                )

type MsgID = ByteString
type Key = ByteString
type Value = ByteString
type StreamName = String

readStream :: IsStream t => StreamName -> t Redis StreamsRecord
readStream streamId = readStreamStartingFrom streamId "$"

readStreamStartingFrom
    :: IsStream t => StreamName -> MsgID -> t Redis StreamsRecord
readStreamStartingFrom streamId =
    Streamly.unfold $ readStartingFromUnfold streamId

readStartingFromUnfold :: StreamName -> Unfold Redis MsgID StreamsRecord
readStartingFromUnfold streamIn = Unfold.many
    (Unfold.unfoldrM $ getResponseStep streamIn)
    Unfold.fromList
  where
    getResponseStep streamIn oldRecordId = do
        let xReadOpts = Redis.defaultXreadOpts { Redis.block = Just 0 }
        result <- Redis.xreadOpts [(Ch8.pack streamIn, oldRecordId)] xReadOpts
        case result of
            Right (Just xResponses) -> do
                    -- Should be one response for one stream
                let records =
                        concat
                            [ Redis.records xResponse
                            | xResponse <- xResponses
                            ]  -- , stream xResponse == Ch8.pack streamIn
                    lastRecordId = recordId . Prelude.last $ records
                pure $ Just (records, lastRecordId)
            Right Nothing -> pure $ Just ([], oldRecordId)
            Left  err     -> throwM err

sendStream
    :: IsStream t
    => StreamName
    -> t Redis (ByteString, ByteString)
    -> t Redis (Either Reply ByteString)
sendStream streamOut = Streamly.mapM step
    where step (key, value) = sendUpstream streamOut key value


