" left = [lnum, col]
" right = [lnum, col]
" left < right -> 1
" left = right -> 0
" left > right -> -1
function utils#compare_pos(left, right) abort
  return a:left[0] < a:right[0] ? 1
        \ : a:left[0] > a:right[0] ? -1
        \ : a:left[1] == a:right[1] ? 0
        \ : a:left[1] < a:right[1] ? 1
        \ : -1
endfunction

" from, to: 2点のバイト座標
" opts.auto_swap: trueの場合、fromとtoの前後を気にしない
" opts.exclusive: trueの場合、最後の文字は含まない
function utils#get_string(from, to, opts = {}) abort
  let compared = utils#compare_pos(a:from, a:to)
  if compared < 0 && !get(a:opts, 'auto_swap', v:false)
    return ''
  endif

  let [from, to] = compared >= 0 ? [a:from, a:to] : [a:to, a:from]

  let lines = getline(from[0], to[0])
  let from_idx = from[1]-1
  let to_idx = to[1]-1
  let last_line_till_pos = to_idx > 0 ? lines[-1][0 : to_idx-1] : ''
  let last_char = get(a:opts, 'exclusive', v:false) ? '' : lines[-1][to_idx : ]->slice(0, 1)
  let lines[-1] = last_line_till_pos .. last_char
  let lines[0] = lines[0][from_idx : ]
  return join(lines, "\n")
endfunction

" e.g. <space> -> \<space>
function utils#trans_special_key(str) abort
  return substitute(a:str, '<[^>]*>', {m -> eval($'"\{m[0]}"')}, 'g')
endfunction

function utils#uniq_add(list, item) abort
  if index(a:list, a:item) < 0
    call add(a:list, a:item)
  endif
endfunction

function utils#echoerr(...) abort
  echohl ErrorMsg
  for str in a:000
    echomsg '[tuskk]' str
  endfor
  echohl NONE
endfunction

function utils#debug_log(contents) abort
  let contents = type(a:contents) == v:t_list ? mapnew(a:contents, 'json_encode(v:val)')
        \ : type(a:contents) == v:t_dict ? json_encode(a:contents)
        \ : [a:contents]
  call writefile(contents, './debug.log', 'a')
endfunction

let consonant_list = [
      \ 'aあ', 'iい', 'uう', 'eえ', 'oお',
      \ 'kかきくけこ', 'gがぎぐげご',
      \ 'sさしすせそ', 'zざじずぜぞ',
      \ 'tたちつてとっ', 'dだぢづでど',
      \ 'nなにぬねのん',
      \ 'hはひふへほ', 'bばびぶべぼ', 'pぱぴぷぺぽ',
      \ 'mまみむめも',
      \ 'yやゆよ',
      \ 'rらりるれろ',
      \ 'wわを',
      \ ]
let s:consonant_dict = {}
for c in consonant_list
  let [a; japanese] = split(c, '\zs')
  for j in japanese
    let s:consonant_dict[j] = a
  endfor
endfor

function utils#consonant(char) abort
  return get(s:consonant_dict, a:char, '')
endfunction

function utils#consonant1st(str) abort
  return utils#consonant(utils#firstchar(a:str))
endfunction

function utils#firstchar(str) abort
  return a:str->substitute('^.\zs.*$', '', '')
endfunction

function utils#lastchar(str) abort
  return a:str->substitute('^.*\ze.$', '', '')
endfunction

function utils#leftchar() abort
  let line = getline('.')
  let lastidx = col('.')-2
  if line ==# '' || lastidx < 0
    return ''
  endif
  return line[:lastidx]->utils#lastchar()
endfunction

function utils#hasunprintable(str) abort
  return a:str !~ '\p' || a:str =~ "\<bs>"
endfunction

function utils#ifempty(item, fallback) abort
  return a:item->empty() ? a:fallback : a:item
endfunction

function utils#strsplit(str) abort
  " 普通にsplitすると<bs>など<80>k?のコードを持つ文字を正しく切り取れないので対応
  let chars = split(a:str, '\zs')
  let prefix = split("\<bs>", '\zs')
  let result = []
  let i = 0
  while i < len(chars)
    if chars[i] == prefix[0] && chars[i+1] == prefix[1]
      call add(result, chars[i : i+2]->join(''))
      let i += 2
    else
      call add(result, chars[i])
    endif
    let i += 1
  endwhile
  return result
endfunction

function utils#do_user(event_name) abort
  if exists($'#User#{a:event_name}')
    execute $'doautocmd User {a:event_name}'
  endif
endfunction

function utils#strcmp(left, right) abort
  return a:left ==# a:right ? 0 : a:left ># a:right ? 1 : -1
endfunction

" run last one call in wait time
" https://github.com/lambdalisue/gin.vim/blob/937cc4dd3b5b1fbc90a21a8b8318b1c9d2d7c2cd/autoload/gin/internal/util.vim
let s:debounce_timers = {}
function utils#debounce(fn, wait, args = [], timer_name = '') abort
  let timer_name = a:timer_name !=# '' ? a:timer_name
        \ : type(a:fn) == v:t_string ? a:fn
        \ : string(a:fn)
  call get(s:debounce_timers, timer_name, 0)->timer_stop()
  " workaround: neovimでなぜかa:argsが効かないため変数化
  let args = a:args
  let s:debounce_timers[timer_name] = timer_start(a:wait, {-> call(a:fn, args) })
endfunction
