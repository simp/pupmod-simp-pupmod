# @summary Options for one entry of a list parameter
#
# An empty Hash means `{ ensure => present }`. New options are added here
# as Optional keys, so existing data keeps validating.
type Pupmod::EntryOptions = Struct[{ Optional['ensure'] => Enum['present', 'absent'] }]
