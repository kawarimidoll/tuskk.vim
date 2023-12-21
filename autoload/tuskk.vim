" vim 2146以前ではE340が出るため使用不可 https://github.com/vim/vim/issues/13609
if !exists('*keytrans') || exists(':defer') != 2 || (!has('nvim') && !has('patch-9.0.2146'))
  call tuskk#utils#echoerr('このバージョンの' .. v:progname .. 'はサポートしていません')
  finish
elseif !executable('rg')
  call tuskk#utils#echoerr('ripgrep (rg) が必要です https://github.com/BurntSushi/ripgrep')
  finish
endif

" function import system
let s:sid_functions = {}
function s:import(filename) abort
  let path = $"{expand('<script>:p:h')}/{a:filename}.vim"
  execute 'source' path
  let sid = getscriptinfo({'name': path})[0].sid
  let functions = getscriptinfo({'sid': sid})[0].functions
  let filename = substitute(a:filename, '.*/', '', '')
  let prefix = '^<SNR>\d\+_export_'
  for funcname in functions
    if funcname =~ prefix
      let keyname = filename .. substitute(funcname, prefix, '#', '')
      let s:sid_functions[keyname] = funcname
    endif
  endfor
endfunction
function s:f(funcname, ...) abort
  return call(s:sid_functions[a:funcname], a:000)
endfunction

call s:import('phase')
call s:import('henkan_list')

function s:feed(str) abort
  call feedkeys(a:str, 'ni')
endfunction

function s:current_complete_item() abort
  return s:latest_henkan_item
endfunction
function s:is_tuskk_completed() abort
  return !empty(s:current_complete_item())
endfunction

function tuskk#clear_state(set_reason = 'clear_state') abort
  call s:f('store#hide')
  call s:f('store#clear')
  call phase#set('hanpa', a:set_reason)
  let s:latest_henkan_item = {}
  let s:last_machi = ''

  " kouho状態の判定は他のphaseとは独立して判定する
  let s:phase_kouho = v:false
endfunction

function tuskk#enable() abort
  if s:is_enable
    return
  endif
  call tuskk#utils#do_user('tuskk_enable_pre')
  defer tuskk#utils#do_user('tuskk_enable_post')

  augroup tuskk_inner_augroup
    autocmd!
    autocmd CompleteChanged * call s:on_complete_changed(v:event)
    " 変換が確定したらlatest_henkan_itemをクリアする
    " is_tuskk_completedがfalseなのにselectedが有効値の場合は
    " このプラグイン以外の候補が選択されたと判断して状態をクリアする
    autocmd CompleteDone *
          \   if s:is_tuskk_completed()
          \ |   let s:latest_henkan_item = {}
          \ | elseif complete_info().selected >= 0
          \ |   call tuskk#clear_state('CompleteDone')
          \ | endif
    " InsertLeaveだと<c-c>を使用した際に発火しないため
    " ModeChangedを使用する
    autocmd ModeChanged i:*
          \   if mode(1) !~ '^n\?i'
          \ |   call tuskk#disable()
          \ | endif
  augroup END

  let s:keys_to_remaps = []
  let sid = "\<sid>"
  for [key, val] in items(tuskk#opts#get('map_keys_dict'))
    if index(['|', ''''], key) >= 0
      continue
    endif
    let current_map = maparg(key, 'i', 0, 1)
    let k = keytrans(key)
    call add(s:keys_to_remaps, empty(current_map) ? k : current_map)
    execute $"inoremap {k} <cmd>call {sid}ins('{keytrans(k)}', {val})<cr>"
  endfor

  if tuskk#opts#get('textwidth_zero')
    let s:save_textwidth = &textwidth
    set textwidth=0
  endif

  call tuskk#mode#clear()
  call tuskk#clear_state('enable')

  let s:is_enable = v:true
endfunction

function tuskk#disable(escape = v:false) abort
  if !s:is_enable
    return
  endif
  call tuskk#utils#do_user('tuskk_disable_pre')
  defer tuskk#utils#do_user('tuskk_disable_post')

  autocmd! tuskk_inner_augroup

  let after_feed = (s:f('store#is_present', 'kouho') ? s:f('store#get', 'kouho') : s:f('store#get', 'machi'))
        \ .. s:f('store#get', 'okuri') .. s:f('store#get', 'hanpa')

  for k in s:keys_to_remaps
    try
      if type(k) == v:t_string
        execute 'iunmap' k
      else
        call mapset('i', 0, k)
      endif
    catch
      echomsg k v:exception
    endtry
  endfor

  if has_key(s:, 'save_textwidth')
    let &textwidth = s:save_textwidth
    unlet! s:save_textwidth
  endif

  call tuskk#mode#clear()
  call tuskk#clear_state('disable')

  let s:is_enable = v:false
  if mode() !=# 'i'
    return
  endif
  if a:escape
    let after_feed ..= "\<esc>"
  endif
  call s:feed(after_feed)
endfunction

function tuskk#toggle() abort
  return s:is_enable ? tuskk#disable() : tuskk#enable()
endfunction

function tuskk#init(opts = {}) abort
  call tuskk#utils#do_user('tuskk_initialize_pre')
  defer tuskk#utils#do_user('tuskk_initialize_post')
  call s:import('tuskk/opts')
  call s:import('tuskk/store')
  call s:import('tuskk/user_jisyo')
  call s:import('tuskk/cmd_buf')

  try
    call s:f('opts#parse', a:opts)
  catch
    call tuskk#utils#echoerr($'[init] {v:exception}', 'abort')
    return
  endtry

  let s:is_enable = v:false
endfunction

" p1からp2までのバッファの文字列を変換する
" p1, p2: 2点のバイト座標
" opts.okuri: 送り文字列
" opts.exclusive: trueの場合、最後の文字は含まない
" opts.stay: trueの場合、machi状態になるだけで変換は行なわない
function tuskk#henkan_buffer(p1, p2, opts = {}) abort
  let exclusive = get(a:opts, 'exclusive', v:false)
  if a:p1[0] != a:p2[0]
    call tuskk#utils#echoerr('同じ行である必要があります')
    return
  elseif a:p1[1] == a:p2[1] && exclusive
    call tuskk#utils#echoerr('異なる列である必要があります')
    return
  endif

  let machi = tuskk#utils#get_string(a:p1, a:p2, {'auto_swap': v:true, 'exclusive': exclusive})
  let okuri = get(a:opts, 'okuri', '')
  if !okuri->empty() && machi =~# okuri .. '$'
    let machi = substitute(machi, okuri .. '$', '', '')
  endif

  call cursor(tuskk#utils#compare_pos(a:p1, a:p2) > 0 ? a:p2 : a:p1)

  let stay = get(a:opts, 'stay', v:false)
  let s:henkan_buffer_context = { 'machi': machi, 'okuri': okuri, 'stay': stay }
  let feed = "\<esc>"
  let feed ..= exclusive ? 'i' : 'a'
  let feed ..= $"\<cmd>call {expand('<SID>')}henkan_buffer_2()\<cr>"
  call s:feed(feed)
endfunction
" feedkeysを挟んだ処理の前後関係を保証するため、関数を複数に分ける
function s:henkan_buffer_2() abort
  let target = s:henkan_buffer_context.machi .. s:henkan_buffer_context.okuri
  let feed = repeat("\<bs>", strcharlen(target))
  let feed ..= $"\<cmd>call tuskk#enable()\<cr>\<cmd>call {expand('<SID>')}henkan_buffer_3()\<cr>"
  call s:feed(feed)
endfunction
function s:henkan_buffer_3() abort
  call s:f('store#set', 'machi', s:henkan_buffer_context.machi)
  call s:f('store#set', 'okuri', s:henkan_buffer_context.okuri)
  let next_phase = s:henkan_buffer_context.okuri ==# '' ? 'machi' : 'okuri'
  call phase#set(next_phase, 'henkan_buffer')
  call s:display_marks()
  if s:henkan_buffer_context.stay
    return
  endif
  let feed = s:henkan_start()
  call s:feed(feed)
endfunction
" xnoremap K <cmd>call tuskk#henkan_buffer(getpos('.')[1:2], getpos('v')[1:2], {'okuri':'り'})<cr>
" xnoremap K <cmd>call tuskk#henkan_buffer(getpos('.')[1:2], getpos('v')[1:2], {'stay':1})<cr>

function s:on_kakutei_special(user_data) abort
  let context = a:user_data.context
  let yomi = a:user_data.yomi
  let special = a:user_data.special

  if special ==# 'google'
    let google_result = tuskk#google_cgi#henkan(yomi)
    if google_result ==# ''
      call tuskk#utils#echoerr('Google変換で結果が得られませんでした。')
      return
    endif

    let comp_list = [s:make_special_henkan_item({
          \ 'abbr': google_result,
          \ 'menu': 'Google変換',
          \ 'yomi': yomi,
          \ 'special': 'set_to_user_jisyo',
          \ 'skip_put': v:false,
          \ })]

    call complete(context.pos[1], comp_list)
    return
  endif

  if special ==# 'set_to_user_jisyo'
    let menu = context.menu ==# '' ? '' : $';{context.menu}'
    let line = $'{yomi} /{context.abbr}{menu}/'
    call writefile([line], tuskk#opts#get('user_jisyo_path'), "a")
    return
  endif

  if special ==# 'new_word'
    call s:f('user_jisyo#add_word', context)
    return
  endif

  call tuskk#utils#echoerr('未実装 ' .. special)
endfunction

function s:on_complete_changed(event) abort
  let user_data = get(a:event.completed_item, 'user_data', {})

  " user_dataがない、またはあってもyomiがない場合は
  " このプラグインとは関係ない候補
  let s:latest_henkan_item = (type(user_data) != v:t_dict || !has_key(user_data, 'yomi'))
        \ ? {}
        \ : a:event.completed_item

  " kouhoを設定
  " 有効な候補が無い場合は空文字
  " skip_putが存在する場合は変換をバッファに反映せず読みをそのまま表示
  " それ以外は普通の候補なのでabbrを表示
  let kouho = empty(s:latest_henkan_item) ? ''
        \ : get(user_data, 'skip_put', v:false) ? user_data.yomi
        \ : get(s:latest_henkan_item, 'abbr', '')
  call s:f('store#set', 'kouho', kouho)
  call s:display_marks()
endfunction

function s:get_spec(key) abort
  " 先行入力と合わせて
  "   完成した
  "     辞書
  "     文字列
  "       半端がある
  "       半端がない→半端が空文字として判断できる
  "   完成していないが次なる先行入力の可能性がある
  " 先行入力を無視して単体で
  "   完成した→直前の先行入力を消すか分岐する必要がある
  "     辞書
  "     文字列
  "       半端がある
  "       半端がない→半端が空文字として判断できる
  "   完成していないが次なる先行入力の可能性がある
  " 完成していないし先行入力にもならない

  " string: バッファに書き出す文字列
  " store: ローマ字入力バッファの文字列（上書き）
  " その他：関数など func / mode / expr
  let spec = { 'string': '', 'store': '', 'key': a:key }

  let current = s:f('store#get', 'hanpa') .. a:key
  if has_key(tuskk#opts#get('kana_table'), current)
    let spec.reason = 'combined:found'
    " s:store.hanpaの残存文字と合わせて完成した場合
    if type(tuskk#opts#get('kana_table')[current]) == v:t_dict
      call extend(spec, tuskk#opts#get('kana_table')[current])
      return spec
    endif
    let [kana, roma; _rest] = tuskk#opts#get('kana_table')[current]->split('\A*\zs') + ['']
    let spec.string = kana
    let spec.store = roma
    return spec
  elseif has_key(tuskk#opts#get('preceding_keys_dict'), current)
    let spec.reason = 'combined:probably'
    " 完成はしていないが、先行入力の可能性がある場合
    let spec.store = current
    return spec
  endif

  " ここまでで値がヒットせず、put_hanpaがfalseなら、
  " storeに残っていた半端な文字をバッファに載せずに消す
  let spec.string = tuskk#opts#get('put_hanpa') ? s:f('store#get', 'hanpa') : ''

  if has_key(tuskk#opts#get('kana_table'), a:key)
    let spec.reason = 'alone:found'
    " 先行入力を無視して単体で完成した場合
    if type(tuskk#opts#get('kana_table')[a:key]) == v:t_dict
      call extend(spec, tuskk#opts#get('kana_table')[a:key])
      " 値が辞書ならput_hanpaに関らずstringは削除
      " storeに値を保存する
      let spec.string = ''
      let spec.store = s:f('store#get', 'hanpa')
    else
      let [kana, roma; _rest] = tuskk#opts#get('kana_table')[a:key]->split('\A*\zs') + ['']
      let spec.string ..= kana
      let spec.store = roma
    endif

    return spec
  elseif has_key(tuskk#opts#get('preceding_keys_dict'), a:key)
    let spec.reason = 'alone:probably'
    " 完成はしていないが、単体で先行入力の可能性がある場合
    let spec.store = a:key
    return spec
  endif

  let spec.reason = 'unfound'
  " ここまで完成しない（かなテーブルに定義が何もない）場合
  let spec.string ..= a:key
  let spec.store = ''
  return spec
endfunction

function s:henkan_fuzzy() abort
  let exact_match = s:f('store#get', 'machi')->strcharlen() < tuskk#opts#get('suggest_prefix_match_minimum')
  call henkan_list#update_fuzzy_v2(s:f('store#get', 'machi'), exact_match)
  let comp_list = copy(henkan_list#get_fuzzy())
  if mode() !=# 'i'
    " タイマー実行しており、さらに変換リストの構築に時間がかかるため、
    " この時点で挿入モードから抜けてしまっている可能性がある
    return
  elseif s:phase_kouho
    " 手動変換が開始していたら何もしない
    return
  elseif empty(comp_list) && pumvisible()
    call s:feed("\<c-e>")
    return
  endif
  let machi_pos = s:f('store#getpos', 'machi')
  let col = machi_pos->empty() ? col('.') : machi_pos[1]
  call complete(col, comp_list)
endfunction

function s:make_special_henkan_item(opts) abort
  let yomi = get(a:opts, 'yomi', s:f('store#get', 'machi'))
  let okuri = get(a:opts, 'okuri', s:f('store#get', 'okuri'))
  let pos = getpos('.')[1:2]
  let menu = get(a:opts, 'menu', '')

  let user_data = {
        \ 'yomi': yomi,
        \ 'len': strcharlen(yomi),
        \ 'special': a:opts.special,
        \ 'skip_put': get(a:opts, 'skip_put', v:true)
        \ }
  let user_data.context = {
        \   'abbr': a:opts.abbr,
        \   'menu': menu,
        \   'pos': pos,
        \   'machi': yomi,
        \   'okuri': okuri,
        \   'consonant': tuskk#utils#consonant1st(okuri),
        \   'is_trailing': pos[1] == col('$')
        \ }
  return {
        \ 'word': '', 'abbr': a:opts.abbr, 'menu': menu,
        \ 'empty': v:true, 'dup': v:true, 'user_data': user_data
        \ }
endfunction

function s:henkan_start() abort
  call henkan_list#update_manual_v2(s:f('store#get', 'machi'), s:f('store#get', 'okuri'))
  let comp_list = copy(henkan_list#get())
  let list_len = len(comp_list)

  if list_len == 1 && tuskk#opts#get('kakutei_unique')
    call s:f('store#clear', )
    call phase#set('hanpa', 'kakutei_unique')
    return comp_list[0].abbr
  endif

  if tuskk#opts#get('use_google_cgi')
    call add(comp_list, s:make_special_henkan_item({
          \ 'abbr': '[Google変換]',
          \ 'special': 'google'
          \ }))
  endif
  call add(comp_list, s:make_special_henkan_item({
        \ 'abbr': '[辞書登録]',
        \ 'special': 'new_word'
        \ }))

  call complete(col('.'), comp_list)
  let s:phase_kouho = v:true
  return list_len > 0 ? "\<c-n>" : ''
endfunction

function s:zengo(key) abort
  if s:f('store#is_present', 'hanpa')
    " ひらがなになりきれていない文字が残っている場合はスキップ
    return ''
  endif
  if phase#is('okuri')
  " nop
  elseif phase#is('machi')
    call s:f('store#push', 'machi', a:key)
    let feed = s:henkan('')
  else
    call phase#set('machi', 'zengo: start machi')
    let feed = a:key
  endif
  return feed
endfunction

function s:sticky() abort
  if s:f('store#is_present', 'hanpa')
    " ひらがなになりきれていない文字が残っている場合はスキップ
    return ''
  endif

  if phase#is('machi')
    if s:f('store#is_present', 'machi')
      call phase#set('okuri', 'sticky: start okuri')
    endif
  elseif phase#is('okuri')
  " nop
  else
    call phase#set('machi', 'sticky: start machi')
  endif
  return ''
endfunction

function s:backspace() abort
  let feed = ''
  if s:f('store#is_present', 'hanpa')
    call s:f('store#pop', 'hanpa')
  elseif s:f('store#is_present', 'okuri')
    call s:f('store#pop', 'okuri')
    if s:f('store#is_blank', 'okuri')
      call phase#set('machi', 'backspace: blank okuri')
    endif
  elseif s:f('store#is_present', 'machi')
    call s:f('store#pop', 'machi')
    if s:f('store#is_blank', 'machi')
      call phase#set('hanpa', 'backspace: blank machi')
      if tuskk#mode#is_start_sticky()
        call tuskk#mode#set('hira')
      endif
    endif
  else
    let feed = "\<bs>"
  endif
  return feed
endfunction

function s:kakutei(fallback_key) abort
  call phase#set('hanpa', 'kakutei')
  let feed = (s:f('store#is_present', 'kouho') ? s:f('store#get', 'kouho') : s:f('store#get', 'machi')) .. s:f('store#get', 'okuri')
  call s:f('store#clear', 'kouho')
  call s:f('store#clear', 'machi')
  call s:f('store#clear', 'okuri')
  if tuskk#mode#is_start_sticky()
    call tuskk#mode#set('hira')
  endif
  return feed ==# '' ? tuskk#utils#trans_special_key(a:fallback_key) : feed
endfunction

function s:henkan(fallback_key) abort
  let feed = ''
  if s:f('store#is_present', 'okuri')
    return "\<c-n>"
  elseif s:f('store#is_present', 'machi')
    if s:phase_kouho
      return "\<c-n>"
    endif
    if tuskk#opts#get('trailing_n') && s:f('store#get', 'hanpa') ==# 'n' && s:f('store#get', 'machi')->slice(-1) != 'ん'
      call s:f('store#push', 'machi', 'ん')
    endif
    let feed = s:henkan_start()
  else
    let feed = s:f('store#get', 'hanpa') .. tuskk#utils#trans_special_key(a:fallback_key)
  endif
  call s:f('store#clear', 'hanpa')
  return feed
endfunction

function s:ins(key, with_sticky = v:false) abort
  call phase#forget()
  if a:with_sticky && !(a:key =~ '^[!-~]$' && tuskk#mode#is_direct())

    " TODO direct modeの変換候補を選択した状態で大文字を入力した場合の対処
    let feed = s:handle_spec({ 'string': '', 'store': '', 'func': 'sticky' })

    let key = a:key->tolower()
    call s:feed(tuskk#utils#trans_special_key(feed) .. $"\<cmd>call {expand('<SID>')}ins('{key}')\<cr>")
    return
  endif

  let spec = s:get_spec(a:key)

  let func = get(spec, 'func', '')
  let mode = get(spec, 'mode', '')
  if s:is_tuskk_completed() && mode ==# '' && index(['kakutei', 'backspace', 'henkan'], func) < 0
    let feed = s:handle_spec({ 'string': '', 'store': '', 'key': '', 'func': 'kakutei' })
    call s:feed(tuskk#utils#trans_special_key(feed) .. $"\<cmd>call {expand('<SID>')}ins('{a:key}')\<cr>")
    return
  endif

  let feed = s:handle_spec(spec)

  if phase#is('machi') && s:last_machi != s:f('store#get', 'machi') && tuskk#opts#get('suggest_wait_ms') >= 0
    call tuskk#utils#debounce(funcref('s:henkan_fuzzy'), tuskk#opts#get('suggest_wait_ms'))
  endif
  let s:last_machi = s:f('store#get', 'machi')

  if feed ==# ''
    call s:display_marks()
    if phase#was('machi') && phase#is('hanpa') && pumvisible()
      call s:feed("\<c-e>")
    endif
  else
    call s:feed(tuskk#utils#trans_special_key(feed) .. $"\<cmd>call {expand('<SID>')}display_marks()\<cr>")
  endif
endfunction

function s:handle_spec(args) abort
  let spec = a:args

  if !s:is_tuskk_completed() && get(spec, 'key', '') =~ '^[!-~]$' && tuskk#mode#is_direct()
    let spec = { 'string': spec.key, 'store': '', 'key': spec.key }
  endif

  call s:f('store#set', 'hanpa', spec.store)

  " kouho状態に入る(継続する)かのフラグ
  let next_kouho = v:false

  " 多重コンバートを防止
  let allow_convert = v:true

  " 末尾でstickyを実行するかどうかのフラグ
  " 変換候補選択中にstickyを実行した場合、いちど確定してからstickyを実行するため、
  " このフラグを見て実行を後回しにする必要がある
  let after_sticky = v:false

  let feed = ''
  if has_key(spec, 'func')
    " handle func
    if spec.func ==# 'sticky'
      if s:is_tuskk_completed()
        let feed = s:kakutei('')
        let after_sticky = v:true
      else
        let feed = s:sticky()
      endif

    elseif spec.func ==# 'backspace'
      let feed = s:backspace()
    elseif spec.func ==# 'kakutei'
      if s:is_tuskk_completed()
        let user_data = s:current_complete_item()->get('user_data', {})
        if type(user_data) == v:t_dict && has_key(user_data, 'special')
          call timer_start(0, {->s:on_kakutei_special(user_data)})
        endif
      endif
      let feed = s:kakutei(spec.key) .. s:f('store#get', 'hanpa')
      call s:f('store#clear', )
    elseif spec.func ==# 'henkan'
      let feed = s:henkan(spec.key)
      let next_kouho = v:true
    elseif spec.func ==# 'zengo'
      if s:is_tuskk_completed()
        let feed = s:kakutei('')
        let feed ..= s:zengo(spec.key)
      else
        let feed = s:zengo(spec.key)
      endif
    elseif spec.func ==# 'extend'
      call s:f('store#hide', )
      let char = tuskk#utils#leftchar()
      " 現状、ひらがなのみ対応
      if char =~ '^[ぁ-ゖ]$'
        call s:f('store#unshift', 'machi', char)
        let feed = "\<bs>"
        if phase#is('hanpa')
          call phase#set('machi', 'extend: start machi')
        endif
      endif
    elseif spec.func ==# 'shrink'
      call s:f('store#hide', )
      if s:f('store#is_present', 'machi')
        let char = s:f('store#shift', 'machi')
        " machi状態のままバッファを変更するため、bsを仕込む
        " (不可視文字を入れるとバッファを変更するようにしているため)
        let feed = char .. char .. "\<bs>"
        if s:f('store#is_blank', 'machi')
          call phase#set('hanpa', 'shrink: blank machi')
        endif
      endif
    else
      call tuskk#utils#echoerr('定義されていないfuncが使われました')
    endif
  elseif has_key(spec, 'mode')
    if s:f('store#is_present', 'okuri')
    " nop
    elseif s:f('store#is_present', 'machi')
      if s:phase_kouho
      " nop
      else
        let feed ..= tuskk#mode#convert_alt(spec.mode, s:kakutei(''))
        let allow_convert = v:false
      endif
    else
      call tuskk#mode#set_alt(spec.mode)
      if tuskk#mode#is_start_sticky()
        let after_sticky = v:true
      endif
    endif
  elseif has_key(spec, 'expr')
    let feed = call(spec.expr, get(spec, 'args', []))
  elseif has_key(spec, 'call')
    call call(spec.call, get(spec, 'args', []))
  else
    if s:is_tuskk_completed()
      let feed = s:kakutei('')
    endif
    let feed ..= spec.string
  endif

  let s:phase_kouho = next_kouho

  if allow_convert
    " TODO カタカナモードでも変換できるようにする
    let feed = tuskk#mode#convert(feed)
  endif

  if after_sticky
    let feed ..= $"\<cmd>call {expand('<SID>')}sticky()\<cr>"
  endif

  if phase#is('hanpa') || tuskk#utils#hasunprintable(feed)
    return feed
  elseif phase#is('machi')
    if tuskk#opts#get('auto_henkan_characters') =~# tuskk#utils#lastchar(feed)
      " ** EXPERIMENTAL **
      " machi状態でauto_henkan_charactersに含まれる文字が入力されたら
      " それをokuriに指定して送り変換を開始する
      call s:f('store#push', 'okuri', tuskk#utils#lastchar(feed))
      return s:henkan_start()
    else
      call s:f('store#push', 'machi', feed)
    endif
  elseif phase#is('okuri')
    call s:f('store#push', 'okuri', feed)

    if s:f('store#is_blank', 'hanpa')
      return s:henkan_start()
    endif
  endif
  return ''
endfunction

function s:display_marks(...) abort
  let hlname = tuskk#opts#get('highlight_hanpa')
  if hlname == ''
    let [lnum, col] = getpos('.')[1:2]
    let syn_offset = (col > 1 && col == col('$')) ? 1 : 0
    let hlname = synID(lnum, col-syn_offset, 1)->synIDattr('name')
  endif

  let mark_process_list = []

  if phase#is('machi')
    let hlname = tuskk#opts#get('highlight_machi')
  endif
  if s:f('store#is_present', 'kouho')
    call add(mark_process_list, ['clear', 'machi'])
    let hlname = tuskk#utils#ifempty(tuskk#opts#get('highlight_kouho'), hlname)
    call add(mark_process_list, ['put', 'kouho', hlname])
  elseif s:f('store#is_present', 'machi')
    call add(mark_process_list, ['clear', 'kouho'])
    let hlname = tuskk#utils#ifempty(tuskk#opts#get('highlight_machi'), hlname)
    call add(mark_process_list, ['put', 'machi', hlname])
  else
    call add(mark_process_list, ['clear', 'kouho'])
    call add(mark_process_list, ['clear', 'machi'])
  endif
  if phase#is('okuri')
    let hlname = tuskk#utils#ifempty(tuskk#opts#get('highlight_okuri'), hlname)
  endif
  if s:f('store#is_present', 'okuri')
    call add(mark_process_list, ['put', 'okuri', hlname])
  else
    call add(mark_process_list, ['clear', 'okuri'])
  endif
  if s:f('store#is_present', 'hanpa')
    call add(mark_process_list, ['put', 'hanpa', hlname])
  else
    call add(mark_process_list, ['clear', 'hanpa'])
  endif

  if has('nvim')
    " vimとneovimでは同一座標にmarkが打たれたときの表示順が逆
    call reverse(mark_process_list)
  endif

  for process in mark_process_list
    if process[0] ==# 'clear'
      call s:f('store#hide', process[1])
    else
      call s:f('store#show', process[1], process[2])
    endif
  endfor
endfunction
