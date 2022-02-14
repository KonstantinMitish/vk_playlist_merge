fs = require 'fs'
easyvk = require 'easyvk'
_ = require 'lodash'
readline = require 'readline'

rl = readline.createInterface
  input: process.stdin,
  output: process.stdout

captchaHandler = (captcha, solve) ->

  rl.question "Введите капчу для картинки #{captcha.captcha_img}\n", (key) ->
    try 
        await captcha.resolve(key)
    catch o
        console.log 'Капче не решена!!!\nПробуем занова'
        o.reCall()


token = process.env.TOKEN
config = require './config'

try 
    vk = await easyvk
        token: token
        #captchaHandler: captchaHandler
    
    load_playlist = (owner, id = undefined, max = undefined) -> 
        result = []
        offset = 0
        count = config.step
        while offset < count 
            response = await vk.call 'audio.get',
                owner_id: owner
                album_id: id
                offset: offset
                count: max || config.step
            result = result.concat response.items
            count = max || response.count
            offset += response.items.length
        result

    main_playlist = await load_playlist config.result.owner, config.result.id
    fs.writeFileSync "test.json", JSON.stringify main_playlist, null, 4

    check_duplicate = (audio) ->
       copy = _.find main_playlist, (i) ->
            i.artist == audio.artist &&
            i.title == audio.title &&
            i.duration == audio.duration &&
            i.id != audio.id

        copy != undefined


    # check duplicates
    check_duplicates_all = () ->
        duplicates = []
        for audio in main_playlist
            if check_duplicate audio
                duplicates.push audio
        duplicates = _.uniqBy duplicates, (i) ->
            i.artist + i.title + i.duration

        list = _.map duplicates, (audio) ->
            "#{audio.title} - #{audio.artist}"

        console.log list

    check_duplicates_all()
    

    add_buffer = []
    add = (audio) ->
        add_buffer.push audio

    flush = () ->
        if !add_buffer.length
            console.log "empty add buffer"
            return
        message = "added #{add_buffer.length} new tracks\n"

        list = _.map add_buffer, (audio) ->
            message += "#{audio.artist} - #{audio.title}\n"
            main_playlist.push audio
            "#{audio.owner_id}_#{audio.id}"

        await vk.call 'messages.send',
            peer_id: config.dialog
            message: message
            random_id: easyvk.randomId()

        response = await vk.call 'audio.addToPlaylist',
            owner_id: config.result.owner
            playlist_id: config.result.id
            audio_ids: list.join ','

        await vk.call 'messages.send',
            peer_id: config.dialog
            message: "response: \n\n #{JSON.stringify response}"
            random_id: easyvk.randomId()

    # check users
    for user in config.users
        pl = await load_playlist user, undefined, config.count
        for item in pl
            if !check_duplicate item
                add item
        await flush()
    
    # check playlists
    for playlist in config.playlists
        pl = await load_playlist playlist.owner, playlist.id, config.count
        for item in pl
            if !check_duplicate item
                add item
        await flush()

catch error
    console.log error

