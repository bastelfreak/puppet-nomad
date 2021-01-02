# == Class: nomad
#
# Installs, configures, and manages nomad
#
# === Parameters
#
# [*version*]
#   Specify version of nomad binary to download.
#
# [*config_hash*]
#   Use this to populate the JSON config file for nomad.
#
# [*config_mode*]
#   Use this to set the JSON config file mode for nomad.
#
# [*pretty_config*]
#   Generates a human readable JSON config file. Defaults to `false`.
#
# [*pretty_config_indent*]
#   Toggle indentation for human readable JSON file. Defaults to `4`.
#
# [*install_method*]
#   Valid strings: `package` - install via system package
#                  `url`     - download and extract from a url. Defaults to `url`.
#                  `none`    - disable install.
#
# [*package_name*]
#   Only valid when the install_method == package. Defaults to `nomad`.
#
# [*package_ensure*]
#   Only valid when the install_method == package. Defaults to `installed`.
#
#
# [*restart_on_change*]
#   Determines whether to restart nomad agent on $config_hash changes.
#   This will not affect reloads when service, check or watch configs change.
# Defaults to `true`.
#
# [*extra_options*]
#   Extra arguments to be passed to the nomad agent
#
# [*init_style*]
#   What style of init system your system uses.
#
# [*purge_config_dir*]
#   Purge config files no longer generated by Puppet
class nomad (
  $manage_user           = true,
  $user                  = 'nomad',
  $manage_group          = true,
  $extra_groups          = [],
  $purge_config_dir      = true,
  $group                 = 'nomad',
  $join_wan              = false,
  $bin_dir               = '/usr/local/bin',
  $arch                  = $nomad::params::arch,
  $version               = $nomad::params::version,
  $install_method        = $nomad::params::install_method,
  $os                    = $nomad::params::os,
  $download_url          = undef,
  $download_url_base     = $nomad::params::download_url_base,
  $download_extension    = $nomad::params::download_extension,
  $package_name          = $nomad::params::package_name,
  $package_ensure        = $nomad::params::package_ensure,
  $config_dir            = '/etc/nomad',
  $extra_options         = '',
  $config_hash           = {},
  $config_defaults       = {},
  $config_mode           = $nomad::params::config_mode,
  $pretty_config         = false,
  $pretty_config_indent  = 4,
  $service_enable        = true,
  $service_ensure        = 'running',
  $manage_service        = true,
  $restart_on_change     = true,
  $init_style            = $nomad::params::init_style,
) inherits nomad::params {
  $real_download_url    = pick($download_url, "${download_url_base}${version}/${package_name}_${version}_${os}_${arch}.${download_extension}")

  validate_bool($purge_config_dir)
  validate_bool($manage_user)
  validate_array($extra_groups)
  validate_bool($manage_service)
  validate_bool($restart_on_change)
  validate_hash($config_hash)
  validate_hash($config_defaults)
  validate_bool($pretty_config)
  validate_integer($pretty_config_indent)

  $config_hash_real = deep_merge($config_defaults, $config_hash)
  validate_hash($config_hash_real)

  if $config_hash_real['data_dir'] {
    $data_dir = $config_hash_real['data_dir']
  } else {
    $data_dir = undef
  }

  if ($config_hash_real['ports'] and $config_hash_real['ports']['rpc']) {
    $rpc_port = $config_hash_real['ports']['rpc']
  } else {
    $rpc_port = 8400
  }

  if ($config_hash_real['addresses'] and $config_hash_real['addresses']['rpc']) {
    $rpc_addr = $config_hash_real['addresses']['rpc']
  } elsif ($config_hash_real['client_addr']) {
    $rpc_addr = $config_hash_real['client_addr']
  } else {
    $rpc_addr = $facts['networking']['interfaces']['lo']['ip']
  }

  $notify_service = $restart_on_change ? {
    true    => Class['nomad::run_service'],
    default => undef,
  }

  anchor { 'nomad_first': }
  -> class { 'nomad::install': }
  -> class { 'nomad::config':
    config_hash => $config_hash_real,
    purge       => $purge_config_dir,
    notify      => $notify_service,
  }
  -> class { 'nomad::run_service': }
  -> class { 'nomad::reload_service': }
  -> anchor { 'nomad_last': }
}
