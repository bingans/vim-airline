" MIT License. Copyright (c) 2013 Bailey Ling.
" vim: ts=2 sts=2 sw=2 fdm=indent

let s:is_win32term = (has('win32') || has('win64')) && !has('gui_running')
let s:sections = ['a','b','c','gutter','x','y','z','warning']

let s:airline_highlight_map = {
      \ 'mode'           : 'Al2',
      \ 'mode_separator' : 'Al3',
      \ 'info'           : 'Al4',
      \ 'info_separator' : 'Al5',
      \ 'statusline'     : 'Al6',
      \ 'file'           : 'Al7',
      \ }

function! s:create_builder(active)
  let builder = {}
  let builder._sections = []
  let builder._active = a:active

  function! builder.split(gutter)
    call add(self._sections, ['|', a:gutter])
  endfunction

  function! builder.add_section(group, contents)
    call add(self._sections, [a:group, a:contents])
  endfunction

  function! builder.add_raw(text)
    call add(self._sections, ['_', a:text])
  endfunction

  function! builder._group(group)
    return '%#' . (self._active ? a:group : a:group.'_inactive') . '#'
  endfunction

  function! builder.build()
    let line = '%{airline#update_highlight()}'
    let side = 0
    let prev_group = ''
    for section in self._sections
      if section[0] == '|'
        let side = 1
        let line .= '%#'.prev_group.'#'.section[1]
        let prev_group = ''
        continue
      endif
      if section[0] == '_'
        let line .= section[1]
        continue
      endif

      if prev_group != ''
        let line .= side == 0
              \ ? self._group(airline#themes#exec_highlight_separator(section[0], prev_group))
              \ : self._group(airline#themes#exec_highlight_separator(prev_group, section[0]))
        let line .= side == 0
              \ ? self._active ? g:airline_left_sep : g:airline_left_alt_sep
              \ : self._active ? g:airline_right_sep : g:airline_right_alt_sep
      endif

      let line .= self._group(section[0]).section[1]
      let prev_group = section[0]
    endfor
    return line
  endfunction

  return builder
endfunction

function! airline#exec_highlight(group, colors)
  let colors = a:colors
  if s:is_win32term
    let colors = map(a:colors, 'v:val != "" && v:val > 128 ? v:val - 128 : v:val')
  endif
  exec printf('hi %s %s %s %s %s %s %s %s',
        \ a:group,
        \ colors[0] != '' ? 'guifg='.colors[0] : '',
        \ colors[1] != '' ? 'guibg='.colors[1] : '',
        \ colors[2] != '' ? 'ctermfg='.colors[2] : '',
        \ colors[3] != '' ? 'ctermbg='.colors[3] : '',
        \ len(colors) > 4 && colors[4] != '' ? 'gui='.colors[4] : '',
        \ len(colors) > 4 && colors[4] != '' ? 'cterm='.colors[4] : '',
        \ len(colors) > 4 && colors[4] != '' ? 'term='.colors[4] : '')
endfunction

function! airline#reload_highlight()
  call airline#highlight(['inactive'])
  call airline#highlight(['normal'])
  call airline#extensions#load_theme()
endfunction

function! airline#load_theme(name)
  let g:airline_theme = a:name
  let inactive_colors = g:airline#themes#{g:airline_theme}#inactive "also lazy loads the theme
  let w:airline_lastmode = ''
  call airline#reload_highlight()
  call airline#update_highlight()
endfunction

function! airline#highlight(modes)
  " draw the base mode, followed by any overrides
  let mapped = map(a:modes, 'v:val == a:modes[0] ? v:val : a:modes[0]."_".v:val')
  for mode in mapped
    if exists('g:airline#themes#{g:airline_theme}#{mode}')
      for key in keys(g:airline#themes#{g:airline_theme}#{mode})
        let colors = g:airline#themes#{g:airline_theme}#{mode}[key]
        let suffix = a:modes[0] == 'inactive' ? '_inactive' : ''
        call airline#exec_highlight(s:airline_highlight_map[key].suffix, colors)
      endfor
    endif
  endfor
  call airline#themes#exec_highlight_separator('Al2', 'warningmsg')
endfunction

" for 7.2 compatibility
function! s:getwinvar(winnr, key, ...)
  let winvals = getwinvar(a:winnr, '')
  return get(winvals, a:key, (a:0 ? a:1 : ''))
endfunction

function! s:get_section(winnr, key, ...)
  let text = s:getwinvar(a:winnr, 'airline_section_'.a:key, g:airline_section_{a:key})
  let [prefix, suffix] = [get(a:000, 0, '%( '), get(a:000, 1, ' %)')]
  return empty(text) ? '' : prefix.text.suffix
endfunction

function! airline#get_statusline(winnr, active)
  let builder = s:create_builder(a:active)

  if s:getwinvar(a:winnr, 'airline_render_left', a:active || (!a:active && !g:airline_inactive_collapse))
    call builder.add_section('Al2', s:get_section(a:winnr, 'a').'%{g:airline_detect_paste && &paste ? g:airline_paste_symbol." " : ""}')
    call builder.add_section('Al4', s:get_section(a:winnr, 'b'))
    call builder.add_section('Al6', s:get_section(a:winnr, 'c').' %#Al7#%{&ro ? g:airline_readonly_symbol : ""}')
  else
    call builder.add_section('Al6', '%f%m')
  endif
  call builder.split(s:get_section(a:winnr, 'gutter', '', ''))
  if s:getwinvar(a:winnr, 'airline_render_right', 1)
    call builder.add_section('Al6', s:get_section(a:winnr, 'x'))
    call builder.add_section('Al4', s:get_section(a:winnr, 'y'))
    call builder.add_section('Al2', s:get_section(a:winnr, 'z'))
    if a:active
      call builder.add_raw('%(')
      call builder.add_section('warningmsg', s:get_section(a:winnr, 'warning', '', ''))
      call builder.add_raw('%)')
    endif
  endif
  return builder.build()
endfunction

function! airline#exec_funcrefs(list, break_early)
  " for 7.2; we cannot iterate list, hence why we use range()
  " for 7.3-[97, 328]; we cannot reuse the variable, hence the {}
  for i in range(0, len(a:list) - 1)
    let Fn{i} = a:list[i]
    if a:break_early
      if Fn{i}()
        return 1
      endif
    else
      call Fn{i}()
    endif
  endfor
  return 0
endfunction

function! airline#update_statusline()
  if airline#exec_funcrefs(g:airline_exclude_funcrefs, 1)
    call setwinvar(winnr(), '&statusline', '')
    return
  endif

  for nr in filter(range(1, winnr('$')), 'v:val != winnr()')
    call setwinvar(nr, 'airline_active', 0)
    call setwinvar(nr, '&statusline', airline#get_statusline(nr, 0))
  endfor

  let w:airline_active = 1

  unlet! w:airline_render_left
  unlet! w:airline_render_right
  for section in s:sections
    unlet! w:airline_section_{section}
  endfor
  call airline#exec_funcrefs(g:airline_statusline_funcrefs, 0)

  call setwinvar(winnr(), '&statusline', airline#get_statusline(winnr(), 1))
endfunction

function! airline#update_highlight()
  if get(w:, 'airline_active', 1)
    let l:m = mode()
    if l:m ==# "i"
      let l:mode = ['insert']
    elseif l:m ==# "R"
      let l:mode = ['replace']
    elseif l:m =~# '\v(v|V||s|S|)'
      let l:mode = ['visual']
    else
      let l:mode = ['normal']
    endif
    let w:airline_current_mode = get(g:airline_mode_map, l:m, l:m)
  else
    let l:mode = ['inactive']
    let w:airline_current_mode = get(g:airline_mode_map, '__')
  endif

  if g:airline_detect_modified && &modified | call add(l:mode, 'modified') | endif
  if g:airline_detect_paste    && &paste    | call add(l:mode, 'paste')    | endif

  let mode_string = join(l:mode)
  if get(w:, 'airline_lastmode', '') != mode_string
    call airline#highlight(l:mode)
    let w:airline_lastmode = mode_string
  endif
  return ''
endfunction
