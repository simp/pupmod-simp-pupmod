# Matches valid puppetserver JAVA memory parameters
type Pupmod::Memory = Pattern['^\d+(g|k|m|%)$']
