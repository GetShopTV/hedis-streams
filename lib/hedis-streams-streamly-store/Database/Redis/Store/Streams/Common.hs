module Database.Redis.Store.Streams.Common where

import Data.Store
import Database.Redis hiding (decode)
import Database.Redis.Streams.Types
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Prelude qualified as Streamly

-- | All redis streams that created by this library use entry field "dstore" to store serialized data.
storeStreamEntryField :: EntryField
storeStreamEntryField = EntryField "dstore"

toStoreEntry :: Store a => a -> Entry
toStoreEntry x = Entry [(storeStreamEntryField, EntryValue $ encode x)]

deserializedStreamsRecordUnfold ::
    Store a => Unfold.Unfold Redis StreamsRecord (MessageID, Either PeekException a)
deserializedStreamsRecordUnfold =
    Unfold.many
        -- Extract stream entries
        -- There always should be one key/value pair in store stream entry
        -- Pair entry with it's message id, decode the value
        ( Unfold.function
            ( \StreamsRecord{recordId, keyValues} ->
                -- Key should be "dstore", but not checked for performance
                -- Allows multiple serialized types in the same message
                fmap (\(_key, value) -> (MessageID recordId, decode value)) keyValues
            )
        ) -- Flatten
        Unfold.fromList