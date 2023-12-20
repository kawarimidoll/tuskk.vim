function s:url_encode(str)
  return range(0, strlen(a:str)-1)
        \ ->map({i -> a:str[i] =~ '[-.~]\|\w' ? a:str[i] : printf("%%%02x", char2nr(a:str[i]))})
        \ ->join('')
endfunction

function google_cgi#henkan(str) abort
  let url_base = 'http://www.google.com/transliterate?langpair=ja-Hira|ja&text='
  let encoded = s:url_encode(a:str)
  let result = system($"curl -s '{url_base}{encoded}'")
  try
    return json_decode(result)->map({_,v->v[1][0]})->join('')
  catch
    echomsg v:exception
    return ''
  endtry
endfunction
