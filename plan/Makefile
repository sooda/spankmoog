spankplan.pdf: spankplan.tex channel.eps filt.eps master.eps osc.eps
	pdflatex $<
	pdflatex $<

%.eps: %.dot
	dot -Teps $< > $@

clean:
	rm -f *.aux *.out *.log *.pdf *.toc *.eps
