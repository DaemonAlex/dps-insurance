fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dps-insurance'
author 'Del Perro Sands'
description 'Ties m-Insurance into the MDT, impound, hospital and medical chart'
version '1.0.0'

dependencies { 'ox_lib', 'oxmysql', 'qbx_core', 'm-Insurance' }

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/logic.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/coverage.lua',
    'server/fines.lua',
}
