# Inflow signal of slow through-plane flow: the slice-column average in `getMz_ss`

> **Erratum (2026-11-03), on separate branches only:** `errata` (from `main`), `dev-inflow-errata`
> and `dev-postISMRM-errata`. The existing branches are deliberately left unchanged, so they remain
> the reproducible default; check out an errata branch to get the fix. From e566edf (2026-03-20) until this
> fix, `getMz_ss` regime 2 ($0 < v < v_c$) evaluated the integer-$u$ column average with
> `u = ceil(vCrit/vel)`. That is exact only when $v_c/v$ is an integer. In between, the result is
> too saturated by up to 12 % of the inflow excess at 40° and 49 % at 90°, and $M_z(v)$ becomes a
> staircase. The fix is the exact column average for any $v_c/v$ (the boxed equation in §2), which
> equals the old value at every integer. The no-velocity call is unchanged. §3 gives the error,
> §6 the affected branches and callers, and §8 how the problem was found.

`getMz_ss(pMri, pRelax, vel)` returns, for spins moving at `vel`, the longitudinal magnetization
that a voxel spanning a 2D slice sees just before an RF pulse. This note derives that quantity,
shows that the previous implementation (`u = ceil(vCrit/vel)`) was exact only when
$v_c/v$ is an integer, and documents the validation in
[`tests/test_getMz_ss.m`](../tests/test_getMz_ss.m).

## 1. Model

The model is a spoiled gradient-echo sequence with flip angle $\alpha$ and repetition time $TR$,
applied to a single rectangular slice of thickness $TH$. Blood flows through the slice
perpendicularly, as plug flow at constant speed $v$. It enters through the slice face fully
relaxed ($M_0$), since nothing upstream is excited.

Write

$$
E_1 = e^{-TR/T_1}, \qquad Q_1 = E_1\cos\alpha, \qquad
M_{ss} = M_0\,\frac{1-E_1}{1-Q_1}, \qquad
v_c = \frac{TH}{TR}.
$$

A spin that has received exactly $m$ earlier pulses carries, just before its next pulse,

$$
M_z(m) = M_{ss} + \left(M_0 - M_{ss}\right) Q_1^{\,m}.
$$

This is the textbook approach to steady state: Brown et al. (2014, eq. 24.5) write it as
$M_z(m^-) = M_{ze} + q^{m-1}(M_0 - M_{ze})$ for the $m$-th pulse, i.e. with $m-1$ earlier pulses.
The signal of that pulse is $M_z(m)\sin\alpha\,e^{-TE/T_2^*}$, which is linear in $M_z$. So the
voxel signal is the average of $M_z$ over the spins in the voxel. Within one column of the slice
all spins share the same $v$ and phase, so this average is also the signal-weighted average.

## 2. Pulse count along the column

Pulses fire at $t_k = k\,TR$. Just before a pulse, a spin at depth $z \in [0, TH)$ below the
entry face entered $z/v$ ago. It has therefore received

$$
m(z) = \left\lfloor \frac{z}{v\,TR} \right\rfloor
$$

earlier pulses. Under steady flow this pattern is the same at every pulse.

Spins are uniform in $z$. Let $x = z/(v\,TR)$, which is uniform on $[0, U]$ with
$U = v_c/v$, and let $K = \lfloor U \rfloor$. The column average is

$$
\left\langle Q_1^{\,m} \right\rangle
= \frac{1}{U}\int_0^{U} Q_1^{\lfloor x \rfloor}\,dx
= \frac{1}{U}\left[\frac{1-Q_1^{K}}{1-Q_1} + (U-K)\,Q_1^{K}\right],
$$

and so

$$
\boxed{\;\overline{M_z}(v) = M_{ss} + \left(M_0-M_{ss}\right)\,
\frac{1}{U}\left[\frac{1-Q_1^{K}}{1-Q_1} + (U-K)\,Q_1^{K}\right],
\qquad 0 < v < v_c\;}
$$

with $\overline{M_z} = M_0$ for $v \ge v_c$ (every spin in the slice entered less than one $TR$
ago) and $\overline{M_z} = M_{ss}$ for $v = 0$. This is what `getMz_ss` now computes.

Special cases:

- **Integer $U = u$.** The bracket becomes $\sum_{m=0}^{u-1} Q_1^m = (1-Q_1^u)/(1-Q_1)$, giving
  $$
  \overline{M_z} = M_{ss} + (M_0-M_{ss})\,\frac{1-Q_1^{u}}{u\,(1-Q_1)} .
  $$
  This is Bianciardi et al. (2016, eq. 2.4) and Brown et al. (2014, eq. 24.9): the average over
  $u$ "velocity segments" that have seen $1, 2, \dots, u$ pulses, the readout pulse included.
  There is no off-by-one between the two counting conventions.
- **$\alpha = 90^\circ$ ($Q_1 = 0$).** $\overline{M_z} = M_{ss} + (M_0-M_{ss})\,v/v_c$, linear in
  $v$ (Bianciardi et al., 2016, eq. 2.6).
- **Continuity.** The expression is continuous in $U$, including at integers, and tends to
  $M_{ss}$ as $v \to 0$ and to $M_0$ as $v \to v_c$.

### Provenance: what comes from the literature and what is derived here

| Ingredient | Peer-reviewed journal articles | Textbooks |
|---|---|---|
| $M_z$ after $m$ pulses, $M_{ss} + (M_0-M_{ss})Q_1^m$ | Ashenagar et al. (2025, eq. 1, which reduces to it when all inter-pulse intervals equal $TR$); Bianciardi et al. (2016, eqs. 2.3–2.4) | Brown et al. (2014, eq. 24.5: valid "as long as the spin is affected by exactly $(m-1)$ pulses"); Kim & Parker (2012, eq. 2.4) |
| A spin at depth $z$ has received a whole number of pulses, $\lfloor z/(v\,TR)\rfloor$; the slice is a stack of segments with different counts | Bianciardi et al. (2016, after eq. 2.4: "the velocity segment that last entered the slice experienced 1 RF pulse, whereas the first entered segment experienced $v_C/v$ RF pulses"); Ashenagar et al. (2025: "when the flow is slow, fluid within the first slice can be divided into partitions each having different amounts of excitation"; each ensemble's excitations are tracked to define $n$); Söderström et al. (2026, §2.5: "the number of RF pulses applied to a specific element") | Brown et al. (2014, §24.1.3: segments of thickness $v\,TR$ that have seen $m = 1,\dots,n$ pulses); Kim & Parker (2012, Fig. 2.1) |
| Voxel signal = volume-weighted average over these segments | Gullberg et al. (1988, abstract: "contributions from a finite number of spin populations, with each population signal weighted by the fractional volume of that spin population"); Gao et al. (1996, eq. 2); Ashenagar et al. (2025: signals "averaged together within each slice"); Söderström et al. (2026, §2.5: "the mean transverse magnetization of all elements localized within the slice") | Brown et al. (2014, eq. 24.9) |
| A population only partly inside the slice still counts, by the volume it occupies there | Gao et al. (1996, eq. 2: $\Delta_{(m,i)}$ is "the volume occupied by the $(m+i)$-labeled spin population in the selected slice", where $m$ is the most-pulsed population "still completely in the selected slice") | |
| Closed form for **integer** $U$: $(1-Q_1^u)/(u(1-Q_1))$ | Bianciardi et al. (2016, eq. 2.4). They write $v_C/v$ in it directly, adding "for the sake of simplicity, we assumed integer values of $v_C/v$". There is no `ceil` in the paper: util added it in e566edf | Brown et al. (2014, eq. 24.9), who assume "an exact integer $n$ of velocity segments" and suggest "a subdivision according to the nearest integer" only "for arbitrary, but large values of $TH/vTR$" |
| Closed form for **any** $U$ (the boxed equation) | **Derived here** from the rows above: the last segment is only partly inside the slice, with weight $(U-K)/U$, as in Gao et al.'s $\Delta_{(m,i)}$. No source states this closed form. It equals the integer form at every integer $U$, and matches a pulse-by-pulse simulation that uses no closed form (§7) | |

So the correction does not rest on Bianciardi et al. (2016) alone. The model (integer pulse counts,
volume-weighted average, partly filled populations included) is stated in peer-reviewed work
(Gullberg et al., 1988; Gao et al., 1996; Ashenagar et al., 2025; Söderström et al., 2026) and in
the textbook treatment Bianciardi et al. cite. Bianciardi et al. supply only its integer-$U$ closed
form, which is where the previous `ceil` came from. The non-integer generalization follows from
that model and is verified numerically.

One consequence: at $\alpha = 90^\circ$ ($Q_1 = 0$) only the newest segment carries the excess.
With $K \ge 1$ the bracket is exactly 1, so the average excess fraction is $1/U = v/v_c$ for
**any** $U$. Bianciardi et al.'s linear eq. 2.6 therefore holds without the integer assumption.
`ceil` replaces $1/U$ with the step function $1/\lceil U\rceil$, which is why its error is largest
at 90° (49 % of the excess).

## 3. What was wrong with `u = ceil(vCrit/vel)`

The previous code applied the integer formula with $u = \lceil v_c/v \rceil$. Bianciardi et al.
(2016) state that they "assumed integer values of $v_C/v$". Brown et al. (2014, §24.1.3) assume
"an exact integer $n$ of velocity segments" and suggest rounding "to the nearest integer" only
for large $n$. Rounding up is exact only at integer $U$. Between integers it treats the whole
column as one pulse more saturated than it is, so $M_z(v)$ becomes a staircase with a step at
every $v = v_c/k$.

There is also a floating-point trap: at $v = v_c/3$, `vCrit/vel` evaluates to
`3.0000000000000004`, and `ceil` returns 4.

The error is largest just below $v_c$, where $u$ jumps from 1 to 2. Pulse-by-pulse reference,
7 T protocol below; error of the inflow excess $\overline{M_z} - M_{ss}$:

| $v/v_c$ | reference $\overline{M_z}/M_0$ | new `getMz_ss` error | previous `ceil(u)` error |
|---|---|---|---|
| 0.03 | 0.1389 | $4\times10^{-6}$ | 2.0 % |
| 0.30 | 0.7519 | $7\times10^{-7}$ | 6.8 % |
| 0.45 | 0.8539 | $2\times10^{-7}$ | 8.2 % |
| 0.70 | 0.9300 | $1\times10^{-7}$ | 5.1 % |
| 0.90 | 0.9767 | $4\times10^{-7}$ | 9.7 % |
| 0.99 | 0.9977 | $4\times10^{-8}$ | 12 % |

At $\alpha = 90^\circ$ (Bianciardi et al.'s protocol) the previous error reached 49 % of the
excess just below $v_c$. The new expression has no steps: the largest jump where $v_c/v$ crosses
an integer is $< 10^{-9}$. With `ceil` it was 0.098 at 40° and 0.164 at 90°, in units of $M_0$.

## 4. Literature: the column average is the standard treatment

Every source read for this note models slow through-plane inflow the same way: a sum over slice
segments (spin populations), each with an integer number of received pulses, weighted by the
volume it occupies.

| Source | Treatment |
|---|---|
| Gullberg et al. (1988) | "The total signal is the sum of the echo amplitudes from each spin population, each weighted by the fractional volume occupied by that population" (spin echo; paraboloid segments for laminar flow). |
| Gao et al. (1996, eq. 2) | Spoiled GRE, laminar flow: $I_b(V) = \sum_{n=1}^{m} M_y^{(n)}(TE)\,V\,TR\,\pi a^2 + \sum_i M_y^{(m+i)}(TE)\,\Delta_{(m,i)}$, a sum over populations that have experienced $n$ pulses, each weighted by its volume. |
| Kim & Parker (2012) | Slow-flow enhancement "can be modeled by subdivision of imaging slices into multiple compartments and summation of the geometric series" (book chapter). |
| Brown et al. (2014, eq. 24.9) | $S = \Lambda\,\tfrac{\sin\theta}{n}\sum_{m=1}^{n}\left[M_{ze} + (M_0-M_{ze})\,q^{m-1}\right]$ (textbook). |
| Bianciardi et al. (2016, eq. 2.4) | The closed form of the sum above, for integer $v_C/v$. |
| Ashenagar et al. (2025) | A dynamic model: each spin ensemble is tracked, its integer number of excitations counted, and signals "averaged together within each slice". |
| Söderström et al. (2026, §2.5) | CSF inflow in fMRI: the slice is divided into elements, each tagged with "the number of RF pulses applied to a specific element", and the signal is "the mean transverse magnetization of all elements localized within the slice". |

Gao & Liu (2012, eq. 1) give a cruder two-compartment sketch,
$S \propto M_{sat}L + (M_{fresh}-M_{sat})V\,TR$. In it only the newest segment is fresh, so it
coincides with the column average only at $Q_1 = 0$.

## 5. Assumptions and limits (unchanged by this fix)

- **Plug flow per call.** For a laminar profile, call `getMz_ss` per spin with that spin's own
  velocity and average the results (as pcMRAsim does). Each radius then gets its own column
  average, which is the paraboloid-segment treatment of Gullberg et al. (1988) and Gao et al.
  (1996).
- **Perpendicular flow.** For a vessel at angle $\theta$ to the slice normal, only the
  through-plane component counts (Kim & Parker, 2012). Pass $v\cos\theta$.
- **Rectangular slice profile** and ideal spoiling. Ashenagar et al. (2025) name the step-function
  profile as a limitation of their model too.
- **Steady flow.** The expression uses the current velocity. For pulsatile flow the pulse count
  depends on the velocity history over the transit time $TH/v$. Ashenagar et al. (2025) show that
  the resulting inflow signal behaves like a low-pass-filtered version of the velocity.
- **Fresh upstream blood.** Single slice, nothing excited upstream.

## 6. Effect on callers

The call signature and outputs are unchanged. Values change only for $0 < v < v_c$ when the
velocities are passed in and $v_c/v$ is not an integer, or is an integer that floating point
pushes just above (as with $v_c/3$). The previous values there were too saturated. The
no-velocity call (default velocity list $v_c/u$ for integer $u$) used the integer $u$ directly,
not `ceil`, so its values are unchanged (to $10^{-9}$).

**Branches carrying the error** (checked 2026-11-03 on every `origin` branch): `main` and every
other branch except `dev-FVEdemoSim`. That includes `dev`, `dev-inflow`, `dev-postISMRM`,
`dev-multiVencISMRM2026`, `dev-qvfMRI`, `dev-xinAndSava2026`, `Miller2026` and `mainLegacy`.
`dev-FVEdemoSim` uses the continuous $u = v_c/v$ instead, which is off by up to +2 % of the excess
(see the frozen record in §8). The fix is **not** merged into any of them, by design: they stay as they were, for
reproducibility. It lives on separate branches: `errata` (from `main`), `dev-inflow-errata` and
`dev-postISMRM-errata`, each its base plus only the erratum commits. Another branch gets the same
treatment by cherry-picking those commits onto a new `<base>-errata` branch.

**Callers that pass velocities** (checked 2026-11-03 in the takoyaki project tree):

| Project | Calls | util it reads |
|---|---|---|
| multiVencISMRM2026 | `doIt.m`, `doIt_inflow.m`, `fitComplexSim.m`, `runSec11.m` | `dev-postISMRM` (`doIt`), `dev-inflow` (`doIt_inflow`) |
| olsFaa2 | `doIt_mouse.m` | its own stripped copy in `devTools/util` (has `ceil`) |
| pcMRAsim, every branch except `main` (`Miller2026`, `dev-xinAndSava2026`, `dev-postISMRM`, `dev-inflow`, `dev-multiVencISMRM2026`, `dev-FVEdemoSim`, `dev-qvfMRI`) | `simVesselSpins` | whichever util the calling project loads |

microscopyValidation calls `getMz_ss` without velocities (unaffected), but its pcMRAsim
`Miller2026` simulation does call it per spin. olsFaa and modulatedIrf hold stripped copies with
`ceil`, but their scripts do not call `getMz_ss`.

## 7. Validation

[`tests/test_getMz_ss.m`](../tests/test_getMz_ss.m) builds a pulse-by-pulse reference. 200 003
spins with stratified entry times cross a rectangular slice; each spin's received pulses are
counted from its entry time, and its $M_z$ is evolved explicitly
($M_z \leftarrow M_z\cos\alpha\,E_1 + M_0(1-E_1)$). The column average just before a pulse is
then compared with `getMz_ss`. Protocols tested:

- 7 T 2D spoiled GRE (TR 8.4 ms, 40°, 1.2 mm, blood $T_1$ 2.58 s);
- Bianciardi et al.'s experiment 1 (TR 33 ms, 90°, 1.2 mm, $T_1$ 2.5 s);
- a low-flip-angle case (TR 20 ms, 10°, 2 mm, $T_1$ 1.6 s).

Checks: agreement with the reference ($< 2\times10^{-5}\,M_0$; observed $\le 2.5\times10^{-6}\,M_0$,
the reference's own sampling error),
equality with Bianciardi eq. 2.4 at integer $U$ ($10^{-12}$), linearity at 90°, no step at
integer $U$, both limits, and the default velocity list. Run:

```matlab
addpath(utilDir); addpath(fullfile(utilDir,'tests')); test_getMz_ss
```

## 8. How this was found

The error turned up on 2026-11-02, while the vesTrack project was porting pcMRAsim's inflow model
to synthesize vessel time series. The question was whether the existing models account for the
spread of pulse counts along the slice column. The investigation:

- derived the column average from first principles;
- checked it against a pulse-by-pulse recursion;
- compared every variant in util and pcMRAsim (`ceil`, continuous $u$, and the 3D per-isochromat
  count);
- read the sources in §4 in full text.

The write-up is kept unedited as a frozen record:
[`docs/errata/inflowCheck-2026-11-02.md`](errata/inflowCheck-2026-11-02.md). The 3D
per-isochromat model had a related error, fixed separately on pcMRAsim branch
`dev-erratum-inflowCount` (`docs/inflowPulseCount.md` there).

## References

How each source was read:

- **Full text, 2026-11-03:**
  - Bianciardi et al. (2016), PMC4822444, equations read from their images;
  - Ashenagar et al. (2025), PMC12319909;
  - Söderström et al. (2026), PMC13418971;
  - Brown et al. (2014) §24.1 and Gao et al. (1996), from the PDFs.
- **Full text, 2026-11-02** (the investigation in §8):
  - Gullberg et al. (1988), pp. 437–439 only; its abstract was re-read on 2026-11-03;
  - Kim & Parker (2012), pp. 39–42 only;
  - Gao & Liu (2012).
- **Not read:** Gao, Holland & Gore (1988, *Med. Phys.* 15:809), which Gao et al. (1996) cite for
  the details of their eq. 2. It is not used as a source here.

Every DOI was resolved on 2026-11-03, and its title and first author checked.

Ashenagar, B., Gomez, D. E. P., & Lewis, L. D. (2025). Modeling dynamic inflow effects in fMRI to
quantify cerebrospinal fluid flow. *Imaging Neuroscience*, 3, IMAG.a.9.
https://doi.org/10.1162/imag.a.9

Bianciardi, M., Toschi, N., Polimeni, J. R., Evans, K. C., Bhat, H., Keil, B., Rosen, B. R.,
Boas, D. A., & Wald, L. L. (2016). The pulsatility volume index: an indicator of cerebrovascular
compliance based on fast magnetic resonance imaging of cardiac and respiratory pulsatility.
*Philosophical Transactions of the Royal Society A*, 374(2067), 20150184.
https://doi.org/10.1098/rsta.2015.0184

Brown, R. W., Cheng, Y.-C. N., Haacke, E. M., Thompson, M. R., & Venkatesan, R. (2014). MR
angiography and flow quantification. In *Magnetic Resonance Imaging: Physical Principles and
Sequence Design* (2nd ed., pp. 701–737). Wiley. https://doi.org/10.1002/9781118633953.ch24
(textbook)

Gao, J.-H., & Liu, H.-L. (2012). Inflow effects on functional MRI. *NeuroImage*, 62(2), 1035–1039.
https://doi.org/10.1016/j.neuroimage.2011.09.088

Gao, J.-H., Miller, I., Lai, S., Xiong, J., & Fox, P. T. (1996). Quantitative assessment of blood
inflow effects in functional MRI signals. *Magnetic Resonance in Medicine*, 36(2), 314–319.
https://doi.org/10.1002/mrm.1910360219

Gullberg, G. T., Simons, M. A., & Wehrli, F. W. (1988). A mathematical model for signal from spins
flowing during the application of spin echo pulse sequences. *Magnetic Resonance Imaging*, 6(4),
437–461. https://doi.org/10.1016/0730-725X(88)90481-X

Kim, S.-E., & Parker, D. L. (2012). Time-of-flight angiography. In J. C. Carr & T. J. Carroll
(Eds.), *Magnetic Resonance Angiography: Principles and Applications* (pp. 39–50). Springer.
https://doi.org/10.1007/978-1-4419-1686-0_2 (book chapter)

Söderström, P., Björnfot, C., Andersson, B. M., Malm, J., Eklund, A., & Wåhlin, A. (2026).
Quantifying cardiac, respiratory, and low frequency components of CSF motion from fMRI inflow
effects. *Magnetic Resonance in Medicine*, 96(4), 1916–1928. https://doi.org/10.1002/mrm.70438
