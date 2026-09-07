(define memories
  '((block cstack (size #x0080))

    (memory program
            (address (#x2001 . #xbfff))
            (type any)
            (section (programStart #x2001)
                     (startup #x200e)))

    (memory zeroPage
            (address (#x2 . #x7f))
            (type ram)
            (qualifier zpage)
            (section (registers #x2)))

    (memory stackPage
            (address (#x100 . #x1ff))
            (type ram))

	(memory freeSpace
			(address (#x1600 . #x1eff))
			(section bss zpsave))
    ))