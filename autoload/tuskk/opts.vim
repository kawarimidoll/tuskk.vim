function tuskk#opts#builtin_kana_table() abort
  let path = expand('<script>:p:h:h:h') .. '/resources/kana_table.json'
  return json_decode(join(readfile(path), "\n"))
endfunction

function tuskk#opts#builtin_auto_henkan_characters() abort
  return 'を、。．，？」！；：);:）”】』》〉｝］〕}]?.,!'
endfunction

function s:create_file(path) abort
  call fnamemodify(a:path, ':p:h')
        \ ->iconv(&encoding, &termencoding)
        \ ->mkdir('p')
endfunction

function s:export_parse(opts) abort
  " 入力中ハイライト
  let s:highlight_hanpa = get(a:opts, 'highlight_hanpa', '')
  let s:highlight_machi = get(a:opts, 'highlight_machi', 'Search')
  let s:highlight_kouho = get(a:opts, 'highlight_kouho', 'IncSearch')
  let s:highlight_okuri = get(a:opts, 'highlight_okuri', 'ErrorMsg')

  " " デバッグログ出力先パス
  " let s:debug_log_path = get(a:opts, 'debug_log_path', '')->expand()
  " if !empty(s:debug_log_path)
  "   if isdirectory(s:debug_log_path)
  "     throw $"debug_log_path is directory {s:debug_log_path}"
  "   endif
  "   " 指定されたパスにファイルがなければ作成する
  "   if glob(s:debug_log_path)->empty()
  "     call s:create_file(s:debug_log_path)
  "   endif
  " endif

  " 自動補完待機時間 (負数の場合は自動補完しない)
  let s:suggest_wait_ms = get(a:opts, 'suggest_wait_ms', -1)
  " 自動補完候補順序 jisyo / code / length
  let s:suggest_sort_by = get(a:opts, 'suggest_sort_by', 'jisyo')
  " 自動補完前方一致最小文字数
  let s:suggest_prefix_match_minimum = get(a:opts, 'suggest_prefix_match_minimum', 5)

  " 自動変換文字 変換待ち状態でこれらの文字が入力されたら即座に変換を行う
  let s:auto_henkan_characters = get(a:opts, 'auto_henkan_characters', '')

  " enable時にtextwidthを0にする
  let s:textwidth_zero = get(a:opts, 'textwidth_zero', v:false)

  " 手動変換で候補が一つしかない場合に自動的に確定する
  let s:kakutei_unique = get(a:opts, 'kakutei_unique', v:false)

  " Google CGI変換
  let s:use_google_cgi = get(a:opts, 'use_google_cgi', v:false)

  " 'っ'が連続したら1回と見做す
  " ex: けっっか→結果
  let s:merge_tsu = get(a:opts, 'merge_tsu', v:false)

  " 末尾の'n'を'ん'と見做す
  " ex: へんかn→変換
  let s:trailing_n = get(a:opts, 'trailing_n', v:false)

  " 辞書の見出しの'ゔ'と'う゛'の表記揺れを吸収する
  let s:smart_vu = get(a:opts, 'smart_vu', v:false)

  " 登場頻度の少ないぁぃぅぇぉゎゕゖの大文字小文字を区別しない
  " ゃゅょっは区別する
  let s:awk_ignore_case = get(a:opts, 'awk_ignore_case', v:false)

  " 辞書検索時に大文字小文字を区別しない(abbrevモードでのみ意味がある)
  let abbrev_ignore_case = get(a:opts, 'abbrev_ignore_case', v:false)

  " かな入力中に確定しないアルファベットを削除する
  let s:put_hanpa = get(a:opts, 'put_hanpa', v:false)

  let rg_cmd = 'rg --no-line-number'
  if abbrev_ignore_case
    let rg_cmd ..= ' --ignore-case'
  endif

  " ユーザー辞書
  " デフォルトは~/.cache/vim/SKK-JISYO.user
  let s:user_jisyo_path = get(a:opts, 'user_jisyo_path', '~/.cache/vim/SKK-JISYO.user')->expand()
  if isdirectory(s:user_jisyo_path)
    throw $"user_jisyo_path is directory {s:user_jisyo_path}"
  endif
  " 指定されたパスにファイルがなければ作成する
  if glob(s:user_jisyo_path)->empty()
    call s:create_file(s:user_jisyo_path)
    call writefile([
          \ ';; フォーマットは以下',
          \ ';; yomi /(henkan(;setsumei)?/)+',
          \ ';; コメント行は変更しないでください',
          \ ';;',
          \ ';; okuri-ari entries.',
          \ ';; okuri-nasi entries.',
          \ ], s:user_jisyo_path)
  endif

  " 変換辞書リスト
  let s:jisyo_list = get(a:opts, 'jisyo_list', [])
  if indexof(s:jisyo_list, $'v:val.path ==# "{s:user_jisyo_path}"') < 0
    " ユーザー辞書がリストに無ければ先頭に追加する
    " マークはU エンコードはutf-8
    call insert(s:jisyo_list, { 'path': s:user_jisyo_path, 'encoding': 'utf-8', 'mark': '[U]' })
  endif
  for jisyo in s:jisyo_list
    if jisyo.path =~ ':'
      throw $"jisyo.path must NOT includes ':' {jisyo.path}"
    elseif !filereadable(jisyo.path)
      throw $"jisyo.path can't be read {jisyo.path}"
    endif

    let jisyo.mark = get(jisyo, 'mark', '')
    let encoding = get(jisyo, 'encoding', '') ?? 'auto'
    let jisyo.grep_cmd = $'{rg_cmd} --encoding {encoding} --regexp "^:q:" {jisyo.path}'
  endfor

  " かなテーブル
  let raw_kana_table = get(a:opts, 'kana_table', {})

  let shift_key_list = []
  let s:keymap_dict = {}
  for [k, val] in items(raw_kana_table)
    let keys = tuskk#utils#trans_special_key(k)->tuskk#utils#strsplit()
    let preceding_keys = slice(keys, 0, -1)->join('')
    let start_key = slice(keys, 0, 1)->join('')
    let end_key = slice(keys, -1)->join('')

    if !has_key(s:keymap_dict, end_key)
      let s:keymap_dict[end_key] = {}
    endif
    let s:keymap_dict[end_key][preceding_keys] = val

    " start_keyもkeymap_dictに登録する(入力開始位置の指定のため)
    if !has_key(s:keymap_dict, start_key)
      let s:keymap_dict[start_key] = {}
    endif
    " 文字入力を開始するアルファベットのキーは変換開始キーとして使用する
    if type(val) == v:t_string && start_key =~# '^\l$'
      call tuskk#utils#uniq_add(shift_key_list, toupper(start_key))
    endif
  endfor

  " 入力テーブルに既に含まれている大文字は変換開始に使わない
  call filter(shift_key_list, '!has_key(s:keymap_dict, v:val)')

  let s:map_cmds = []
  for key in s:keymap_dict->keys()
    let k = keytrans(key)
    call add(s:map_cmds, [k, $"inoremap {k} <cmd>call t#ins('{keytrans(k)}')<cr>"])
  endfor
  for k in shift_key_list
    call add(s:map_cmds, [k, $"inoremap {k} <cmd>call t#ins('{tolower(k)}',1)<cr>"])
  endfor

  let s:preceding_keys_dict = {}
  let s:map_keys_dict = {}
  let s:kana_table = {}
  for [k, val] in items(raw_kana_table)
    let key = tuskk#utils#trans_special_key(k)->keytrans()
    let s:kana_table[key] = val

    let chars = tuskk#utils#trans_special_key(k)->tuskk#utils#strsplit()

    let tmp = copy(chars)
    while len(tmp) > 1
      " jsonのキーが'kya'だったら'ky'と'k'を先行入力キーリストに追加する
      call remove(tmp, -1)
      let s:preceding_keys_dict[tmp->join('')] = 1
    endwhile

    for char in chars
      let s:map_keys_dict[char] = 0
    endfor
  endfor

  " [!-~]のキーはjsonに含まれていないものもすべてマッピングする
  " 英字大文字でpreceding_keys_dictにないものは
  " 変換開始キーとなるのでtrueをたてておく
  for nr in range(char2nr('!'), char2nr('~'))
    let c = nr2char(nr)
    let s:map_keys_dict[c] = c =~# '^\u$' && !has_key(s:preceding_keys_dict, c)
  endfor
endfunction

function tuskk#opts#get(name) abort
  try
    return s:[a:name]
  catch /^Vim\%((\a\+)\)\=:E716:/
    call tuskk#utils#echoerr('[opts#get] 存在しないオプションです')
  endtry
endfunction
