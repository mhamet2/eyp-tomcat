define tomcat::agent (
                        $jar_name,
                        $agent_name,
                        $source        = undef,
                        $tar_source    = undef,
                        $file_ln       = undef,
                        $catalina_base = "/opt/${name}",
                        $servicename   = $name,
                        $purge_old     = false,
                        $ensure        = 'present',
                        $comment       = undef
                        $srcdir        = '/usr/local/src',
                      ) {

  if ! defined(Class['tomcat'])
  {
    fail('You must include the tomcat base class before using any tomcat defined resources')
  }

  if($source==undef and $file_ln==undef and $tar_source==undef )
  {
    fail('You have to specify source, tar_source or file_ln')
  }

  if(($source!=undef or $tar_source!=undef) and $file_ln!=undef)
  {
    fail('You cannot specify both source and file_ln')
  }

  if($source!=undef and $tar_source!=undef)
  {
    fail('You cannot specify both source and tar_source')
  }

  if($file_ln!=undef)
  {
    validate_absolute_path($file_ln)
  }

  Exec {
    path => '/usr/sbin:/usr/bin:/sbin:/bin',
  }

  if($servicename!=undef)
  {
    $serviceinstance=Service[$servicename]
  }
  else
  {
    $serviceinstance=undef
  }

  if($purge_old)
  {
    exec{ "purge old ${catalina_base} ${agent_name} ${jar_name}":
      command => "ls ${catalina_base}/${name}/${agent_name}/*jar | grep -v ${jar_name} | grep -E $(echo ${jar_name}.jar | sed 's/^\\(.*\\)-[0-9.]*\\.jar$/\\1/')'-[0-9.]+.jar' | xargs rm",
      onlyif  => "ls ${catalina_base}/${name}/${agent_name}/*jar | grep -v ${jar_name} | grep -E $(echo ${jar_name}.jar | sed 's/^\\(.*\\)-[0-9.]*\\.jar$/\\1/')'-[0-9.]+.jar'",
      notify  => $serviceinstance,
    }
  }

  file { "${catalina_base}/${agent_name}":
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File[$catalina_base],
  }

  if($source!=undef)
  {
    file { "${catalina_base}/${agent_name}/${jar_name}.jar":
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => File["${catalina_base}/${agent_name}"],
      source  => $source,
      notify  => $serviceinstance,
    }
  }

  if($tar_source!=undef)
  {
    exec { "mkdir p ${srcdir} eyp-tomcat agent":
      command => "mkdir -p ${srcdir}",
      creates => $srcdir,
    }

    file { "${srcdir}/${agent_name}.tgz":
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Exec["mkdir p ${srcdir} eyp-tomcat agent"],
      source  => $tar_source,
    }

    exec { "untar ${srcdir}/${agent_name}.tgz":
      command => "tar -xzf ${srcdir}/${agent_name}.tgz -C ${catalina_base}/${agent_name}/ ",
      creates => "${catalina_base}/${agent_name}/${jar_name}.jar",
      notify  => $serviceinstance,
      require => File[ [ "${srcdir}/${agent_name}.tgz", "${catalina_base}/${agent_name}" ] ],
    }
  }

  if($file_ln!=undef)
  {
    file { "${catalina_base}/${agent_name}/${jar_name}.jar":
      ensure  => 'link',
      target  => $file_ln,
      notify  => $serviceinstance,
      require => File["${catalina_base}/${agent_name}"],
    }
  }

  concat::fragment{ "${catalina_base}/bin/setenv.sh javaagent ${agent_name} ${jar_name}":
    target  => "${catalina_base}/bin/setenv.sh",
    order   => '10',
    content => template("${module_name}/multi/setenv_javaagent.erb"),
  }
}
