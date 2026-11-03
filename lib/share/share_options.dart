/// What a network share may add on top of the peers it carries.
///
/// Both extras are opt-in and default off, so a share with neither selected is
/// byte-for-byte the document the app wrote before they existed.
typedef ShareOptions = ({bool includeSelf, bool includeConfigs});

/// The options a share opens with: neither extra travels.
const ShareOptions noShareOptions = (includeSelf: false, includeConfigs: false);

/// Which extras a resolved share can still offer.
///
/// A sender reads this to hide an option its target cannot honour: adding this
/// device needs a dialable listener, and configs need something that differs
/// from the import defaults.
typedef ShareExtras = ({bool selfPeer, bool configs});

/// The extras of a share that can offer none, as a node share always does.
const ShareExtras noShareExtras = (selfPeer: false, configs: false);
