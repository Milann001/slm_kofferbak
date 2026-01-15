fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Milan'
description 'Kofferbak systeem met ox_target en ox_lib'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

dependencies {
    'ox_lib',
    'ox_target'
}