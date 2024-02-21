//
//  FSEvents.swift
//  Watt
//
//  Created by David Albert on 1/14/24.
//

import Foundation
import os

enum FSEvent {
    struct Flags: OptionSet {
        let rawValue: FSEventStreamEventFlags

        static let none =               Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagNone))
        static let mustScanSubDirs =    Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs))
        static let userDropped =        Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped))
        static let kernelDropped =      Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped))
        static let eventIdsWrapped =    Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagEventIdsWrapped))
        static let historyDone =        Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone))
        static let rootChanged =        Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged))
        static let mount =              Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagMount))
        static let unmount =            Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagUnmount))
        static let itemCreated =        Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated))
        static let itemRemoved =        Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved))
        static let itemInodeMetaMod =   Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod))
        static let itemRenamed =        Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed))
        static let itemModified =       Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified))
        static let itemFinderInfoMod =  Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemFinderInfoMod))
        static let itemChangeOwner =    Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemChangeOwner))
        static let itemXattrMod =       Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemXattrMod))
        static let itemIsFile =         Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile))
        static let itemIsDir =          Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir))
        static let itemIsSymlink =      Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsSymlink))
        static let ownEvent =           Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagOwnEvent))
        static let itemIsHardlink =     Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsHardlink))
        static let itemIsLastHardlink = Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsLastHardlink))
        static let itemCloned =         Flags(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCloned))
    }

    enum EventType {
        case generic
        case mustScanSubDirs
        case eventIdsWrapped
        case streamHistoryDone
        case rootChanged
        case volumeMounted
        case volumeUnmounted
        case itemCreated
        case itemRemoved
        case itemInodeMetadataModified
        case itemRenamed
        case itemDataModified
        case itemFinderInfoModified
        case itemOwnershipModified
        case itemXattrModified
        case itemClonedAtPath

        init(_ flags: consuming Flags) {
            flags.formIntersection([.mustScanSubDirs, .eventIdsWrapped, .historyDone, .rootChanged, .mount, .unmount, .itemCreated, .itemRemoved, .itemInodeMetaMod, .itemRenamed, .itemModified, .itemFinderInfoMod, .itemChangeOwner, .itemXattrMod, .itemCloned])
            switch flags {
            case .mustScanSubDirs: self = .mustScanSubDirs
            case .eventIdsWrapped: self = .eventIdsWrapped
            case .historyDone: self = .streamHistoryDone
            case .rootChanged: self = .rootChanged
            case .mount: self = .volumeMounted
            case .unmount: self = .volumeUnmounted
            case .itemCreated: self = .itemCreated
            case .itemRemoved: self = .itemRemoved
            case .itemInodeMetaMod: self = .itemInodeMetadataModified
            case .itemRenamed: self = .itemRenamed
            case .itemModified: self = .itemDataModified
            case .itemFinderInfoMod: self = .itemFinderInfoModified
            case .itemChangeOwner: self = .itemOwnershipModified
            case .itemXattrMod: self = .itemXattrModified
            case .itemCloned: self = .itemClonedAtPath
            default: self = .generic
            }
        }
    }

    enum MustScanSubDirsReason {
        case userDropped
        case kernelDropped

        init?(_ flags: consuming Flags) {
            flags.formIntersection([.userDropped, .kernelDropped])
            switch flags {
            case .userDropped: self = .userDropped
            case .kernelDropped: self = .kernelDropped
            default: return nil
            }
        }
    }

    enum ItemType {
        case file
        case directory
        case symlink
        case hardlink
        case lastHardlink

        init?(_ flags: consuming Flags) {
            flags.formIntersection([.itemIsFile, .itemIsDir, .itemIsSymlink, .itemIsHardlink, .itemIsLastHardlink])
            switch flags {
            case .itemIsFile: self = .file
            case .itemIsDir: self = .directory
            case .itemIsSymlink: self = .symlink
            case .itemIsHardlink: self = .hardlink
            case .itemIsLastHardlink: self = .lastHardlink
            default: return nil
            }
        }
    }

    struct ExtendedData {
        let path: String
        let fileID: Int?
        let docID: Int?

        init(_ data: [String: Any]) {
            self.path = data[kFSEventStreamEventExtendedDataPathKey] as! String
            if let fileID = data[kFSEventStreamEventExtendedFileIDKey] as! NSNumber? {
                self.fileID = Int(truncating: fileID)
            } else {
                self.fileID = nil
            }
            
            if let docID = data[kFSEventStreamEventExtendedDocIDKey] as! NSNumber? {
                self.docID = Int(truncating: docID)
            } else {
                self.docID = nil
            }
        }
    }

    /* For all event types, the “fromUs” var (whether the event comes from us) will only be set to a non-nil value if kFSEventStreamCreateFlagMarkSelf is set.
     *
     * The notion corresponds to the kFSEventStreamEventFlagOwnEvent flag.
     *
     * Note: If kFSEventStreamCreateFlagIgnoreSelf is set in addition to kFSEventStreamCreateFlagMarkSelf, fromUs should always be false.
     * Note2: The flag does not seem to work for whatever reason… We might wanna try disabling SIP and see if flag still does not work ¯\_(ツ)_/¯ */

    /** `kFSEventStreamEventFlagNone` or unknown flag. */
    case generic(path: String, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    /**
     `kFSEventStreamEventFlagMustScanSubDirs`, `kFSEventStreamEventFlagUserDropped` &
     `kFSEventStreamEventFlagKernelDropped`.

     - note: Not sending the event stream id; it probably has no meaning here. */
    case mustScanSubDirs(path: String, reason: MustScanSubDirsReason?, fromUs: Bool?, extendedData: ExtendedData?)

    /**
     `kFSEventStreamEventFlagEventIdsWrapped`

     The important thing to know is you should retrieve the UUID for the monitored device with `FSEventsCopyUUIDForDevice` if
     you plan on saving the event id to replay from the last seen event id when you program relaunch.
     When receiving the “event id wrapped” event, you should retrieve the new UUID for the device because it changes when the event id wraps.
     [More here](https://stackoverflow.com/a/26281273/1152894).

     - note: There is no "fromUs" part in this case because I assume FSEvents will
     not set the OwnEvent flag for this event (it would not make much sense).
     However, I do not have any confirmation from any doc that it is the actual
     behaviour.
     In any case, the event id counter will probably never wrap (too big to wrap). */
    case eventIdsWrapped

    /**
     `kFSEventStreamEventFlagHistoryDone`

     Not called if monitoring started from now. */
    case streamHistoryDone

    /**
     `kFSEventStreamEventFlagRootChanged`

     Not called if `kFSEventStreamCreateFlagWatchRoot` is not set when creating the stream.

     The event id is not sent with this method as it is always 0 (says the doc) for this event.

     - note: I don't know if the “event is from us” flag is set for this event. */
    case rootChanged(path: String, fromUs: Bool?)

    /**
     `kFSEventStreamEventFlagMount`

     - note: I don't know if the “event is from us” flag is set for this event, nor if the event id has any meaning here…
     I don’t know if there is a valid event id for this event (probably not). */
    case volumeMounted(path: String, eventId: FSEventStreamEventId, fromUs: Bool?)

    /**
     `kFSEventStreamEventFlagUnmount`

     - note: I don't know if the “event is from us” flag is set for this event, nor if the event id has any meaning here…
     I don’t know if there is a valid event id for this event (probably not). */
    case volumeUnmounted(path: String, eventId: FSEventStreamEventId, fromUs: Bool?)

    /* **************************************************************************
     * All methods below are called only if kFSEventStreamCreateFlagFileEvents was set when the stream was created… says the doc.
     * But actually, it is not true on Yosemite (not tested on other OSs).
     * The events for file creation, deletion, renaming, etc. are set even when the flag was not set.
     * The only difference is the events are sent for the parent folder only, and not for each file when the flag is not set.
     * ************************************************************************** */

    /* itemType refers to the kFSEventStreamEventFlagItemIsFile, kFSEventStreamEventFlagItemIsDir,
     * kFSEventStreamEventFlagItemIsSymlink, kFSEventStreamEventFlagItemIsHardlink and
     * kFSEventStreamEventFlagItemIsLastHardlink flags. */

    /** `kFSEventStreamEventFlagItemCreated` */
    case itemCreated(path: String, itemType: ItemType?, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    /** `kFSEventStreamEventFlagItemRemoved` */
    case itemRemoved(path: String, itemType: ItemType?, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    /** `kFSEventStreamEventFlagItemInodeMetaMod` */
    case itemInodeMetadataModified(path: String, itemType: ItemType?, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    /**
     `kFSEventStreamEventFlagItemRenamed`

     `path` is either the new name or the old name of the file.
     You should be called twice, once for the new name, once for the old name
     (assuming both names are in the monitored folder or one of their descendants).
     There are no sure way (AFAICT) to know which is which.
     From my limited testing, both events are sent in the same callback call
     (you don’t have the information of the callback call from FSEventsWrapper) at one event interval,
     the first one being the original name, the second one the new name. */
    case itemRenamed(path: String, itemType: ItemType?, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    /** `kFSEventStreamEventFlagItemModified` */
    case itemDataModified(path: String, itemType: ItemType?, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    /** `kFSEventStreamEventFlagItemFinderInfoMod` */
    case itemFinderInfoModified(path: String, itemType: ItemType?, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    /** `kFSEventStreamEventFlagItemChangeOwner` */
    case itemOwnershipModified(path: String, itemType: ItemType?, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    /** `kFSEventStreamEventFlagItemXattrMod` */
    case itemXattrModified(path: String, itemType: ItemType?, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    /**
     `kFSEventStreamEventFlagItemCloned`

     Only available from macOS 10.13 and macCatalyst 11.0, but we cannot use @available on an enum case with associated values. */
    // @available(macOS 10.13, macCatalyst 11.0, *)
    case itemClonedAtPath(path: String, itemType: ItemType?, eventId: FSEventStreamEventId, fromUs: Bool?, extendedData: ExtendedData?)

    init(id: FSEventStreamEventId, flags: Flags, streamFlags: FSEventStream.Flags, path: String, extendedData: ExtendedData?) {
        let fromUs = streamFlags.contains(.markSelf) ? flags.contains(.ownEvent) : nil

        switch EventType(flags) {
        case .generic:
            self = .generic(path: path, eventId: id, fromUs: fromUs, extendedData: extendedData)
        case .mustScanSubDirs:
            self = .mustScanSubDirs(path: path, reason: MustScanSubDirsReason(flags), fromUs: fromUs, extendedData: extendedData)
        case .eventIdsWrapped:
            self = .eventIdsWrapped
        case .streamHistoryDone:
            self = .streamHistoryDone
        case .rootChanged:
            self = .rootChanged(path: path, fromUs: fromUs)
        case .volumeMounted:
            self = .volumeMounted(path: path, eventId: id, fromUs: fromUs)
        case .volumeUnmounted:
            self = .volumeUnmounted(path: path, eventId: id, fromUs: fromUs)
        case .itemCreated:
            self = .itemCreated(path: path, itemType: ItemType(flags), eventId: id, fromUs: fromUs, extendedData: extendedData)
        case .itemRemoved:
            self = .itemRemoved(path: path, itemType: ItemType(flags), eventId: id, fromUs: fromUs, extendedData: extendedData)
        case .itemInodeMetadataModified:
            self = .itemInodeMetadataModified(path: path, itemType: ItemType(flags), eventId: id, fromUs: fromUs, extendedData: extendedData)
        case .itemRenamed:
            self = .itemRenamed(path: path, itemType: ItemType(flags), eventId: id, fromUs: fromUs, extendedData: extendedData)
        case .itemDataModified:
            self = .itemDataModified(path: path, itemType: ItemType(flags), eventId: id, fromUs: fromUs, extendedData: extendedData)
        case .itemFinderInfoModified:
            self = .itemFinderInfoModified(path: path, itemType: ItemType(flags), eventId: id, fromUs: fromUs, extendedData: extendedData)
        case .itemOwnershipModified:
            self = .itemOwnershipModified(path: path, itemType: ItemType(flags), eventId: id, fromUs: fromUs, extendedData: extendedData)
        case .itemXattrModified:
            self = .itemXattrModified(path: path, itemType: ItemType(flags), eventId: id, fromUs: fromUs, extendedData: extendedData)
        case .itemClonedAtPath:
            self = .itemClonedAtPath(path: path, itemType: ItemType(flags), eventId: id, fromUs: fromUs, extendedData: extendedData)
        }
    }
}

final class FSEventStream: Sendable {
    struct Flags: OptionSet {
        let rawValue: FSEventStreamCreateFlags

        static let none =            Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone))
        static let useCFTypes =      Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes))
        static let noDefer =         Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer))
        static let watchRoot =       Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot))
        static let ignoreSelf =      Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagIgnoreSelf))
        static let fileEvents =      Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents))
        static let markSelf =        Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagMarkSelf))
        static let useExtendedData = Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseExtendedData))
        static let fullHistory =     Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagFullHistory))
        static let withDocID =       Flags(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateWithDocID))
    }

    private let streamRef: FSEventStreamRef
    private let weakRefPtr: UnsafeMutablePointer<Weak<FSEventStream>>
    private let flags: Flags
    private let queue: DispatchQueue
    private let callback: @Sendable (FSEventStream, [FSEvent]) -> Void
    private let isRunning: OSAllocatedUnfairLock<Bool>

    init?(paths: [String], since: FSEventStreamEventId? = nil, latency: CFTimeInterval = 0, flags: Flags = .none, queue: DispatchQueue = .global(), callback: @escaping @Sendable (FSEventStream, [FSEvent]) -> Void) {
        var flags = flags
        flags.insert(.useCFTypes)
        if flags.contains(.withDocID) {
            flags.insert(.useExtendedData)
        }

        self.flags = flags
        self.queue = queue
        self.callback = callback
        self.isRunning = OSAllocatedUnfairLock(initialState: false)

        // TODO: this is almost certainly unsafe because I doubt Weak<FSEventStream> is bitwise copyable. Switch to an Unmanaged reference.
        weakRefPtr = UnsafeMutablePointer<Weak<FSEventStream>>.allocate(capacity: 1)
        weakRefPtr.initialize(to: Weak())

        var context = FSEventStreamContext(
            version: 0,
            info: weakRefPtr,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let streamCallback: FSEventStreamCallback = { streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
            let weakRefPtr = clientCallBackInfo!.assumingMemoryBound(to: Weak<FSEventStream>.self)
            guard let stream = weakRefPtr.pointee.value else {
                return
            }

            let paths: [String]
            let extendedData: [FSEvent.ExtendedData?]
            if stream.flags.contains(.useExtendedData) {
                let data = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [[String: Any]]
                extendedData = data.map { FSEvent.ExtendedData($0) }
                paths = extendedData.map { $0!.path }
            } else {
                paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
                extendedData = Array(repeating: nil, count: numEvents)
            }

            let flags = UnsafeBufferPointer(start: eventFlags, count: numEvents)
            let ids = UnsafeBufferPointer(start: eventIds, count: numEvents)

            let events = zip4(ids, flags, paths, extendedData).map { (id, flags, path, data) in
                FSEvent(
                    id: id,
                    flags: FSEvent.Flags(rawValue: flags),
                    streamFlags: stream.flags,
                    path: path,
                    extendedData: data
                )
            }

            stream.callback(stream, events)
        }

        guard let streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            streamCallback,
            &context,
            paths as CFArray,
            since ?? FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags.rawValue
        ) else {
            return nil
        }
        FSEventStreamSetDispatchQueue(streamRef, queue)

        self.streamRef = streamRef
        weakRefPtr.pointee.value = self
    }

    convenience init?(_ path: String, since: FSEventStreamEventId? = nil, latency: CFTimeInterval = 0, flags: consuming Flags = .none, queue: DispatchQueue = .global(), callback: @escaping @Sendable (FSEventStream, [FSEvent]) -> Void) {
        self.init(paths: [path], since: since, latency: latency, flags: flags, queue: queue, callback: callback)
    }

    deinit {
        stop()

        FSEventStreamInvalidate(streamRef)
        FSEventStreamRelease(streamRef)

        weakRefPtr.deinitialize(count: 1)
        weakRefPtr.deallocate()
    }

    func start() {
        isRunning.withLock { isRunning in
            if isRunning {
                return
            }

            FSEventStreamStart(streamRef)
            isRunning = true
        }
    }

    func stop() {
        isRunning.withLock { isRunning in
            if !isRunning {
                return
            }

            FSEventStreamStop(streamRef)
            isRunning = false
        }
    }
}
