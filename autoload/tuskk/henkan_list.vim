function s:gen_henkan_query(str, opts = {}) abort
  let str = a:str->escape('()[]{}.*+?^$|\')
  if tuskk#opts#get('merge_tsu')
    let str = substitute(str, 'っ\+', 'っ', 'g')
  endif
  if tuskk#opts#get('trailing_n') && !get(a:opts, 'no_trailing_n', v:false)
    let str = substitute(str, 'n$', 'ん', '')
  endif
  if tuskk#opts#get('smart_vu')
    let str = substitute(str, 'ゔ\|う゛', '(ゔ|う゛)', 'g')
  endif
  if tuskk#opts#get('awk_ignore_case')
    let str = str->substitute('あ', '(あ|ぁ)', 'g')
          \ ->substitute('い', '(い|ぃ)', 'g')
          \ ->substitute('う', '(う|ぅ)', 'g')
          \ ->substitute('え', '(え|ぇ)', 'g')
          \ ->substitute('お', '(お|ぉ)', 'g')
          \ ->substitute('わ', '(わ|ゎ)', 'g')
          \ ->substitute('か', '(か|ゕ)', 'g')
          \ ->substitute('け', '(け|ゖ)', 'g')
  endif
  return str
endfunction

function s:parse_henkan_list(lines, jisyo) abort
  if empty(a:lines)
    return []
  endif

  let henkan_list = []

  for line in a:lines
    " よみ /変換1/変換2/.../
    " stridxがバイトインデックスなのでstrpartを使う
    let space_idx = stridx(line, ' /')
    let yomi = strpart(line, 0, space_idx)->trim()
    let henkan_str = strpart(line, space_idx+1)
    for v in split(henkan_str, '/')
      " ;があってもなくても良いよう_restを使う
      let [word, info; _rest] = split(v, ';') + ['']

      " :h complete-items
      call add(henkan_list, {
            \ 'word': '',
            \ 'abbr': word,
            \ 'menu': $'{a:jisyo.mark}{info}',
            \ 'dup': 1,
            \ 'empty': 1,
            \ 'user_data': { 'yomi': yomi, 'path': a:jisyo.path, 'len': strcharlen(yomi) }
            \ })
      " \ 'info': $'{a:jisyo.mark}{info}',
    endfor
  endfor

  return henkan_list
endfunction

function s:populate_henkan_list(query) abort
  let query = a:query
  let numstr_list = query->split('\D\+')
  if !empty(numstr_list)
    let query = query->substitute('\d\+', '#', 'g')
  endif

  let already_add_dict = {}
  let henkan_list = []
  for jisyo in tuskk#opts#get('jisyo_list')
    let lines = jisyo.grep_cmd->substitute(':q:', $'{query} /', '')->systemlist()
    let kouho_list = s:parse_henkan_list(lines, jisyo)
    for kouho in kouho_list
      if !has_key(already_add_dict, kouho.abbr)
        let already_add_dict[kouho.abbr] = 1
        call add(henkan_list, kouho)
      endif
    endfor
  endfor

  if empty(numstr_list)
    return henkan_list
  endif

  " 数値用変換リスト整形
  " 効率的ではないが数値の変換候補はそれほどの量にはならない想定なので気にしない
  let num_henkan_list = []
  for item in henkan_list
    " #4は非対応
    " #9はフォーマットが揃っていなければスキップ
    if item['abbr'] =~ '#4' ||
          \ (item['abbr'] =~ '#9' && (numstr_list->len() > 1 || numstr_list[0] !~ '\d\d'))
      continue
    endif
    for numstr in numstr_list
      let item['abbr'] = item['abbr']->substitute('#0', numstr, '')
            \ ->substitute('#1', tuskk#converters#numconv1(numstr), '')
            \ ->substitute('#2', tuskk#converters#numconv2(numstr), '')
            \ ->substitute('#3', tuskk#converters#numconv3(numstr), '')
            \ ->substitute('#5', tuskk#converters#numconv5(numstr), '')
            \ ->substitute('#8', tuskk#converters#numconv8(numstr), '')
            \ ->substitute('#9', tuskk#converters#numconv9(numstr), '')
    endfor
    call add (num_henkan_list, item)
  endfor
  return num_henkan_list
endfunction

" 送りなし検索→machi='けんさく',okuri=''
" 送りあり検索→machi='しら',okuri='べ'
function tuskk#henkan_list#update_manual(machi, okuri = '') abort
  let query = s:gen_henkan_query(a:machi)
  let suffix = a:okuri ==# '' ? ''
        \ : tuskk#opts#get('auto_henkan_characters') =~# a:okuri ? ''
        \ : tuskk#utils#consonant1st(a:okuri)

  let s:latest_henkan_list = s:populate_henkan_list(query .. suffix)
endfunction

function tuskk#henkan_list#update_suggest(str, exact_match = v:false) abort
  let query = s:gen_henkan_query(a:str)
  let suffix = a:exact_match ? '' : '[^!-~]*'
  let henkan_list = s:populate_henkan_list(query .. suffix)

  if tuskk#opts#get('suggest_sort_by') ==# 'length'
    call sort(henkan_list, {a,b -> a.user_data.len - b.user_data.len})
  elseif tuskk#opts#get('suggest_sort_by') ==# 'code'
    call sort(henkan_list, {a,b -> tuskk#utils#strcmp(a.user_data.yomi, b.user_data.yomi)})
  endif

  let s:latest_suggest_list = henkan_list
endfunction

function tuskk#henkan_list#get_manual() abort
  return get(s:, 'latest_henkan_list', [])
endfunction

function tuskk#henkan_list#get_suggest() abort
  return get(s:, 'latest_suggest_list', [])
endfunction
