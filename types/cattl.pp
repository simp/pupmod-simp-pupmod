# Matches valid Puppet CA TTL configuration
type Pupmod::CaTTL = Variant[
  Integer,
  Pattern[/^\d+[smhdy]$/]
]
