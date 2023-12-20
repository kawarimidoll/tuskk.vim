function tuskk#converters#kata_to_hira(str) abort
  return a:str->substitute('[ァ-ヶ]', {m->nr2char(char2nr(m[0], v:true) - 96, v:true)}, 'g')
endfunction

function tuskk#converters#hira_to_kata(str) abort
  return a:str->substitute('[ぁ-ゖ]', {m->nr2char(char2nr(m[0], v:true) + 96, v:true)}, 'g')
endfunction

function tuskk#converters#hira_to_dakuten(str) abort
  return a:str->substitute('[^[:alnum:][:graph:][:space:]]', {m->m[0] .. '゛'}, 'g')
endfunction

" たまにsplit文字列の描画がおかしくなるので注意
let s:hankana_list = ('ｧｱｨｲｩｳｪｴｫｵｶｶﾞｷｷﾞｸｸﾞｹｹﾞｺｺﾞｻｻﾞｼｼﾞｽｽﾞｾｾﾞｿｿﾞﾀﾀﾞﾁﾁﾞｯﾂﾂﾞﾃﾃﾞﾄﾄﾞ'
      \ .. 'ﾅﾆﾇﾈﾉﾊﾊﾞﾊﾟﾋﾋﾞﾋﾟﾌﾌﾞﾌﾟﾍﾍﾞﾍﾟﾎﾎﾞﾎﾟﾏﾐﾑﾒﾓｬﾔｭﾕｮﾖﾗﾘﾙﾚﾛﾜﾜｲｴｦﾝｳﾞｰｶｹ')
      \ ->split('.[ﾞﾟ]\?\zs')
let s:zen_kata_origin = char2nr('ァ', v:true)
let s:griph_map = { 'ー': '-', '〜': '~', '、': '､', '。': '｡', '「': '｢', '」': '｣', '・': '･' }

function tuskk#converters#zen_kata_to_han_kata(str) abort
  return a:str->substitute('.', {m->get(s:griph_map,m[0],m[0])}, 'g')
        \ ->substitute('[ァ-ヶ]', {m->get(s:hankana_list, char2nr(m[0], v:true) - s:zen_kata_origin, m[0])}, 'g')
        \ ->substitute('[！-～]', {m->nr2char(char2nr(m[0], v:true) - 65248, v:true)}, 'g')
endfunction

function tuskk#converters#hira_to_han_kata(str) abort
  return tuskk#converters#zen_kata_to_han_kata(tuskk#converters#hira_to_kata(a:str))
endfunction

function tuskk#converters#alnum_to_zen_alnum(str) abort
  return tuskk#utils#strsplit(a:str)
        \ ->map({_,c -> c =~ '^[!-~]$' ? nr2char(char2nr(c, v:true) + 65248, v:true) : c})
        \ ->join('')
endfunction

function tuskk#converters#as_is(str) abort
  return a:str
endfunction

" https://zenn.dev/vim_jp/articles/a1f91726d7e656
function tuskk#converters#numconv1(numstr) abort
  return a:numstr->tr('0123456789', '０１２３４５６７８９')
endfunction
function tuskk#converters#numconv2(numstr) abort
  return a:numstr->tr('0123456789', '〇一二三四五六七八九')
endfunction
function tuskk#converters#numconv3(numstr) abort
  return tuskk#converters#numconv5(a:numstr)
        \ ->tr('壱弐参拾', '一二三十')
        \ ->substitute('一\ze[十百千]', '', 'g')
endfunction
function tuskk#converters#numconv5(numstr) abort
  let inner_keta = [''] + '拾百千'->split('\zs')
  let outer_keta = [''] + '万億兆京垓𥝱'->split('\zs')
  return a:numstr->reverse()
        \ ->split('\d\{4}\zs')
        \ ->map({i,v -> outer_keta[i] .. v->split('\zs')->map({j,u -> inner_keta[j] .. u})->filter('v:val !~ "0"')->join('')})
        \ ->join('')
        \ ->tr('123456789', '壱弐参四五六七八九')
        \ ->reverse()
endfunction
function tuskk#converters#numconv8(numstr) abort
  return a:numstr->reverse()->substitute('\d\{3}\ze.', '\0,', 'g')->reverse()
endfunction
function tuskk#converters#numconv9(numstr) abort
  return a:numstr
        \ ->substitute('\d', {m->tr(m[0], '123456789', '１２３４５６７８９')}, '')
        \ ->substitute('\d', {m->tr(m[0], '123456789', '一二三四五六七八九')}, '')
endfunction
