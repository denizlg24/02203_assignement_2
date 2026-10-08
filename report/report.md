# assignment 2 report notes

## Compute Loop

The part of the ASM/FSM that does the compute can be done in a loop fashion. Instead of loading all the 9 pixels around to output a single pixel we can leverage the fact that each memory read reads a word. Each pixel is 8 bits and each word is 32 bits. Loading a buffer word returns pixels $a,b,c,d$ all from the same row. The first 88 words are the first row, the second 88 the second row and so on and so forth.

$\begin{matrix}
a&b&c&d\\
e&f&g&h\\
i&j&k&l
\end{matrix}$

To load this we need to load $w_0$, $w_{88}$ and $w_{176}$.

From here, if we ignore the boundry for now, we can calculate the Sobel operator value for $f$ and $g$.

Then if we keep the last two bytes of each word and load three more words $w_1$, $w_{89}$ and $w_{177}$, we get:

$\begin{matrix}
c&d&m&n&o&p\\
g&h&q&r&s&t\\
k&l&u&v&w&x
\end{matrix}$

from where we can calculate the Sobel operator value for $h$, $q$, $r$, and $s$.

This process can then be repeated horizontally across the row. At each iteration, the last two pixels from each of the three current words are retained, and the next word from each row is loaded. Since each new word contributes four new pixels, each subsequent iteration allows four new output pixels to be computed.

The loop continues until the final word of the current row is reached. Since each row contains (88) buffer words, the horizontal word index ranges from (0) to (87). Special handling is required at the left and right image boundaries, since pixels in columns (0) and (351) do not have a complete (3\times3) neighborhood.

After finishing one output row, the processing window is moved down by one row and the same procedure is repeated. For an output row (r), the three input rows required are (r-1), (r), and (r+1). Therefore, if the current horizontal word index is (k), the three buffer addresses are

$
(r-1)\cdot88+k,\qquad r\cdot88+k,\qquad (r+1)\cdot88+k.
$

The valid Sobel center rows are therefore (1) through (286), while rows (0) and (287) must be handled as image boundaries.