report.pdf: report.tex
	pdflatex $<
	bibtex $(patsubst %.tex,%.aux,$<)
	pdflatex $<
	pdflatex $<

%.eps: %.dot
	dot -Teps $< > $@

clean:
	rm -f *.aux *.out *.log *.pdf *.toc *.eps
