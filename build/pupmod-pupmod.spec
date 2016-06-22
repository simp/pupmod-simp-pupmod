%{lua:

--
-- When you build you must to pass this along so that we know how
-- to get the preliminary information.
-- This directory should hold the following items:
--   * 'build' directory
--   * 'CHANGELOG' <- The RPM formatted Changelog
--   * 'metadata.json'
--
-- Example:
--   rpmbuild -D 'pup_module_info_dir /home/user/project/puppet_module' -ba SPECS/specfile.spec
--

src_dir = rpm.expand('%{pup_module_info_dir}')
if string.match(src_dir, '^%%') then
  src_dir = './'
end

-- These UNKNOWN entries should break the build if something bad happens

module_name = "UNKNOWN"
module_version = "UNKNOWN"
module_license = "UNKNOWN"

-- Default to 0
module_release = '0'

}

%{lua:
-- Pull the Relevant Metadata out of the Puppet module metadata.json.

metadata = ''
metadata_file = io.open(src_dir .. "/metadata.json","r")
if metadata_file then
  metadata = metadata_file:read("*all")
end

-- This starts as an empty string so that we can build it later
module_requires = ''

}

%{lua:

-- Get the Module Name and put it in the correct format

local name_match = string.match(metadata, '"name":%s+"(.-)"%s*,')

if name_match then
  local i = 0
  for str in string.gmatch(name_match,'[^-]+') do
    if i ~= 0 then
      if i == 1 then
        module_name = str
      else
        module_name = (module_name .. '-' .. str)
      end
    end

    i = i+1
  end
end

}

%{lua:

-- Get the Module Version
-- This will not be processed at all

local version_match = string.match(metadata, '"version":%s+"(.-)"%s*,')

if version_match then
  module_version = version_match
end

}

%{lua:

-- Get the Module License
-- This will not be processed at all

local license_match = string.match(metadata, '"license":%s+"(.-)"%s*,')

if license_match then
  module_license = license_match
end

}

%{lua:

-- Get the Module Summary
-- This will not be processed at all

local summary_match = string.match(metadata, '"summary":%s+"(.-)"%s*,')

if summary_match then
  module_summary = summary_match
end

}

%{lua:

-- Get the Module Source line for the URL string
-- This will not be processed at all

local source_match = string.match(metadata, '"source":%s+"(.-)"%s*,')

if source_match then
  module_source = source_match
end

}

%{lua:

-- Snag the RPM-specific items out of the 'build/rpm_metadata' directory

-- First, the Release Number

local rel_file = io.open(src_dir .. "/build/rpm_metadata/release", "r")
if rel_file then
  for line in rel_file:lines() do
    is_comment = string.match(line, "^%s*#")
    is_blank = string.match(line, "^%s*$")

    if not (is_comment or is_blank) then
      module_release = line
      break
    end
  end
end

}

%{lua:

-- Next, the Requirements
local req_file = io.open(src_dir .. "/build/rpm_metadata/requires", "r")
if req_file then
  for line in req_file:lines() do
    valid_line = (string.match(line, "^Requires: ") or string.match(line, "^Obsoletes: ") or string.match(line, "^Provides: "))

    if valid_line then
      module_requires = (module_requires .. "\n" .. line)
    end
  end
end
}

%define module_name %{lua: print(module_name)}
%define base_name pupmod-%{module_name}

%{lua:
-- Determine which Variant we are going to build

local variant = rpm.expand("%{_variant}")
local variant_version = nil

local foo = ""

local i = 0
for str in string.gmatch(variant,'[^-]+') do
  if i == 0 then
    variant = str
  elseif i == 1 then
    variant_version = str
  else
    break
  end

  i = i+1
end

rpm.define("variant " .. variant)

if variant == "pe" then
  rpm.define("puppet_user pe-puppet")
else
  rpm.define("puppet_user puppet")
end

if variant == "pe" then
  if variant_version and ( rpm.vercmp(variant_version,'4') >= 0 ) then
    rpm.define("_sysconfdir /etc/puppetlabs/code")
  else
    rpm.define("_sysconfdir /etc/puppetlabs/puppet")
  end
elseif variant == "p4" then
  rpm.define("_sysconfdir /etc/puppetlabs/code")
else
  rpm.define("_sysconfdir /etc/puppet")
end
}

Summary:   %{module_name} Puppet Module
%if 0%{?_variant:1}
Name:      %{base_name}-%{_variant}
%else
Name:      %{base_name}
%endif

Version:   %{lua: print(module_version)}
Release:   %{lua: print(module_release)}
License:   %{lua: print(module_license)}
Group:     Applications/System
Source:    %{base_name}-%{version}-%{release}.tar.gz
URL:       %{lua: print(module_source)}
BuildRoot: %{_tmppath}/%{base_name}-%{version}-%{release}-buildroot
BuildArch: noarch

%if "%{variant}" == "pe"
Requires: pe-puppet
%else
Requires: puppet
%endif

%{lua: print(module_requires)}

Prefix: %{_sysconfdir}/environments/simp/modules

%description
%{lua: print(module_summary)}

%prep
%setup -q -n %{base_name}-%{version}

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

rm -rf .git
rm -f *.lock
rm -rf spec/fixtures/modules
rm -rf dist
rm -rf junit
rm -rf log

curdir=`pwd`
dirname=`basename $curdir`
cp -r ../$dirname %{buildroot}/%{prefix}/%{module_name}

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

%files
%defattr(0640,root,%{puppet_user},0750)
%{prefix}/%{module_name}

%changelog
%{lua:
-- Finally, the CHANGELOG

-- A default CHANGELOG in case we cannot find a real one

default_changelog = [===[
* $date Auto Changelog <auto@no.body> - $version-$release
- Latest release of $name
]===]

default_lookup_table = {
  date = os.date("%a %b %d %Y"),
  version = module_version,
  release = module_release,
  name = module_name
}

changelog = io.open(src_dir .. "/CHANGELOG","r")
if changelog then
  first_line = changelog:read()
  if string.match(first_line, "^*%s+%a%a%a%s+%a%a%a%s+%d%d?%s+%d%d%d%d%s+.+") then
    changelog:seek("set",0)
    print(changelog:read("*all"))
  else
    print((default_changelog:gsub('$(%w+)', default_lookup_table)))
  end
else
  print((default_changelog:gsub('$(%w+)', default_lookup_table)))
end
}

