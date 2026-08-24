# Finding the most liquid submarket in Dubai's residential real estate

## Why I built this

I wanted to build something that actually used real Dubai data, not another Kaggle CSV dressed up to look local. Most "UAE real estate" portfolio projects I'd seen online were obviously working from fake or generic numbers — you can tell within a minute of looking at them. So I went straight to the source: the Dubai Land Department's own open data portal, which publishes every registered transaction.

The question I wanted to answer: **if you're choosing where to buy a rental property in Dubai, which district actually gives you the best combination of yield and the ability to sell quickly if you need to?** Most yield calculators online only show you one number. They don't tell you whether that number comes with the ability to actually exit the investment when you want to.

## The data

I pulled 1.77 million residential and commercial transactions directly from DLD's open data portal, covering everything registered since [portal history]. I narrowed this down to six districts that cover a spread of Dubai's market — Downtown, Marina, Business Bay, JVC, Palm Jumeirah, and Dubai Hills Estate — and filtered to residential sales only, going back to 2023. That left about 163,000 transactions to work with.

One thing that tripped me up early: DLD doesn't use the district names everyone actually calls these places. "Downtown Dubai" is registered as "Burj Khalifa." "Dubai Marina" is "Marsa Dubai." JVC, somewhat annoyingly, is split across two separate zones — "Al Barsha South Fourth" and "Al Barsha South Fifth" — which I only figured out by searching for buildings I knew were in JVC (Diamond Views, Belgravia) and checking which zone they landed in. If you're doing anything with DLD data yourself, budget time for this — the naming mismatch isn't documented anywhere obvious.

Rent data was harder. DLD does publish rent contract data separately, but the portal's captcha service was down for the entire time I was working on this (it was hitting its own reCAPTCHA quota, not something on my end). Rather than wait indefinitely on a government server, I used published 2026 market rent figures for four of my six districts, and flagged the other two as estimates in my own data tables. I'd rather be upfront about that than pretend every number came from a pristine single source — that's not how real analysis usually works anyway.

## What I actually calculated

Using SQL (MySQL, connected through VS Code), I built a layered query — three chained CTEs — that:

1. Aggregates transactions into average price-per-sqm by district and quarter
2. Uses a `LAG()` window function to calculate quarter-over-quarter price growth per district
3. Uses `RANK()` to rank all six districts against each other by transaction volume, every single quarter — this became my liquidity proxy
4. Joins in the rent and service-charge benchmarks to calculate both gross and net rental yield
5. Combines liquidity rank and net yield into a single weighted "liquidity score" (I weighted it 60% liquidity, 40% yield — more on why below)

The dashboard itself is built in Power BI, connected live to the MySQL database.

## What I found

**JVC was the most liquid district in every single quarter I analyzed**, without exception, despite having some of the lowest average prices in the dataset. That's the headline finding. If exit speed matters to an investor — and for a lot of buy-to-let investors, it does — JVC's consistency here is a stronger signal than any single quarter's yield number.

**Palm Jumeirah sits at the opposite end** — highest average prices, lowest net yield (around 2%), and it consistently ranked last for liquidity. That tracks with what you'd expect: it's an appreciation and prestige play, not an income-generating one.

**Smaller, lower-volume districts show much more volatile quarter-to-quarter price swings** — one of the JVC zones (Al Barsha South Fifth specifically) had a quarter where price jumped 62%, then dropped 15% the next. That's a sample-size effect, not a real market move, and it's worth flagging because it's exactly the kind of thing that would mislead someone reading price charts without checking transaction counts alongside them.

## Why I weighted liquidity over yield (60/40)

This was a judgment call, and I want to be honest that it's a judgment call rather than pretend there's one objectively "correct" weighting. I leaned toward liquidity because, in conversations with people who actually invest in this market, the ability to exit a position without a long holding period or a price haircut tends to matter more than an extra percentage point of yield — especially for anyone not planning to hold for 10+ years. Someone building this for a different investor profile (a long-hold income investor, say) might reasonably flip that weighting. That's the kind of thing I'd want to test against real investor interviews if I took this further.

## What I'd do differently with more time

- Get real DLD rent transaction data once their captcha service is back up, instead of relying on published market averages for two of six districts
- Build out service charge data at the building level rather than a district-wide average — service charges vary a lot within the same district depending on building age and amenities
- Add a proper vacancy-rate assumption into the net yield calculation instead of assuming full occupancy
- Expand past six districts once I'm confident the naming-mapping process is solid, since I had to hand-verify each one this time

## Tools used

SQL (MySQL) for data transformation — CTEs, window functions, joins. Python (pandas) for cleaning, merging multi-part CSV exports, and handling corrupted date values. Power BI for the interactive dashboard, connected live to the database rather than a static export.
