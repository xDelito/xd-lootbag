fx_version 'cerulean'
game 'gta5'

author 'xdelito'
description 'Loot Bag on Death for QBCore'
version '1.0.0'

shared_script '@qb-core/shared/locale.lua'
shared_script 'config.lua'

server_script 'server.lua'
client_script 'client.lua'

dependencies {
    'qb-core',
    'qb-inventory',
    'baseevents'
}
