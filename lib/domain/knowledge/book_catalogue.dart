/// The curated book catalogue and the detailed, computable framework library.
///
/// Two levels:
///  * [kBookCatalogue] — a curated reading list of benchmark investment and
///    quantitative works (title, author, year, category). Entries marked with a
///    Gutenberg id are public domain and the app can fetch them legally.
///  * [kFrameworks] — the frameworks whose *rules* are publicly documented, each
///    with computable criteria and a plain-prose attribution to its source.
///
/// No copyrighted book text is stored here.
library;

import 'book_framework.dart';

// ---------------------------------------------------------------------------
// Curated reading list
// ---------------------------------------------------------------------------

const List<BookRef> kBookCatalogue = [
  // Value
  BookRef(title: 'Security Analysis', author: 'Benjamin Graham & David Dodd', year: 1934),
  BookRef(title: 'The Intelligent Investor', author: 'Benjamin Graham', year: 1949),
  BookRef(title: 'The Little Book That Beats the Market', author: 'Joel Greenblatt', year: 2005),
  BookRef(title: 'You Can Be a Stock Market Genius', author: 'Joel Greenblatt', year: 1997),
  BookRef(title: 'Common Stocks and Uncommon Profits', author: 'Philip Fisher', year: 1958),
  BookRef(title: 'The Essays of Warren Buffett', author: 'Lawrence Cunningham (ed.)', year: 1997),
  BookRef(title: 'Margin of Safety', author: 'Seth Klarman', year: 1991),
  BookRef(title: 'The Most Important Thing', author: 'Howard Marks', year: 2011),
  BookRef(title: 'Value Investing: From Graham to Buffett and Beyond', author: 'Bruce Greenwald', year: 2001),
  BookRef(title: 'Deep Value', author: 'Tobias Carlisle', year: 2014),
  BookRef(title: 'Quantitative Value', author: 'Wesley Gray & Tobias Carlisle', year: 2012),
  BookRef(title: 'The Acquirer\u2019s Multiple', author: 'Tobias Carlisle', year: 2017),
  BookRef(title: 'Quality Investing', author: 'Lawrence Cunningham, Torkell Eide & Patrick Hargreaves', year: 2016),

  // Growth / CAN SLIM
  BookRef(title: 'How to Make Money in Stocks', author: 'William J. O\u2019Neil', year: 1988),
  BookRef(title: 'The CAN SLIM Approach', author: 'William J. O\u2019Neil (IBD methodology)'),
  BookRef(title: 'One Up on Wall Street', author: 'Peter Lynch', year: 1989),
  BookRef(title: 'Beating the Street', author: 'Peter Lynch', year: 1993),
  BookRef(title: 'Learn to Earn', author: 'Peter Lynch', year: 1995),
  BookRef(title: 'Common Stocks and Uncommon Profits', author: 'Philip Fisher', year: 1958),
  BookRef(title: 'Finding the Next Starbucks', author: 'Michael Moe', year: 2006),

  // Momentum / Trend
  BookRef(title: 'Trade Like a Stock Market Wizard', author: 'Mark Minervini', year: 2013),
  BookRef(title: 'Think & Trade Like a Champion', author: 'Mark Minervini', year: 2017),
  BookRef(title: 'Mindset Secrets for Winning', author: 'Mark Minervini', year: 2019),
  BookRef(title: 'Secrets for Profiting in Bull and Bear Markets', author: 'Stan Weinstein', year: 1988),
  BookRef(title: 'Trend Following', author: 'Michael Covel', year: 2004),
  BookRef(title: 'The Complete TurtleTrader', author: 'Michael Covel', year: 2007),
  BookRef(title: 'Way of the Turtle', author: 'Curtis Faith', year: 2007),
  BookRef(title: 'Trade Your Way to Financial Freedom', author: 'Van K. Tharp', year: 1998),
  BookRef(title: 'Technical Analysis of the Financial Markets', author: 'John J. Murphy', year: 1999),
  BookRef(title: 'Japanese Candlestick Charting Techniques', author: 'Steve Nison', year: 1991),
  BookRef(title: 'Reminiscences of a Stock Operator', author: 'Edwin Lef\u00e8vre', year: 1923, gutenbergId: 60920),
  BookRef(title: 'How to Trade in Stocks', author: 'Jesse Livermore', year: 1940),
  BookRef(title: 'The New Market Wizards', author: 'Jack Schwager', year: 1992),
  BookRef(title: 'Market Wizards', author: 'Jack Schwager', year: 1989),
  BookRef(title: 'Trading in the Zone', author: 'Mark Douglas', year: 2000),
  BookRef(title: 'The Disciplined Trader', author: 'Mark Douglas', year: 1990),
  BookRef(title: 'Stock Trading & Investing Using Volume Price Analysis', author: 'Anna Coulling', year: 2013),

  // Quality / Compounding
  BookRef(title: 'The Little Book That Builds Wealth', author: 'Pat Dorsey', year: 2008),
  BookRef(title: 'The Five Rules for Successful Stock Investing', author: 'Pat Dorsey', year: 2004),
  BookRef(title: '100 to 1 in the Stock Market', author: 'Thomas Phelps', year: 1972),
  BookRef(title: 'The Coffee Can Portfolio', author: 'Robert G. Kirby', year: 1984),
  BookRef(title: 'The Snowball', author: 'Alice Schroeder', year: 2008),

  // Factor / Quant
  BookRef(title: 'Active Portfolio Management', author: 'Richard Grinold & Ronald Kahn', year: 1999),
  BookRef(title: 'Quantitative Equity Portfolio Management', author: 'Ludwig Chincarini & Daehwan Kim', year: 2006),
  BookRef(title: 'Expected Returns', author: 'Antti Ilmanen', year: 2011),
  BookRef(title: 'Your Complete Guide to Factor-Based Investing', author: 'Andrew Berkin & Larry Swedroe', year: 2016),
  BookRef(title: 'A Practitioner\u2019s Guide to Factor Models', author: 'CFA Institute Research Foundation', year: 1994),
  BookRef(title: 'Advances in Financial Machine Learning', author: 'Marcos L\u00f3pez de Prado', year: 2018),
  BookRef(title: 'Machine Learning for Asset Managers', author: 'Marcos L\u00f3pez de Prado', year: 2020),
  BookRef(title: 'Algorithmic Trading', author: 'Ernest Chan', year: 2013),
  BookRef(title: 'Quantitative Trading', author: 'Ernest Chan', year: 2008),
  BookRef(title: 'Trading and Exchanges', author: 'Larry Harris', year: 2002),
  BookRef(title: 'Evidence-Based Technical Analysis', author: 'David Aronson', year: 2006),
  BookRef(title: 'Fooled by Randomness', author: 'Nassim Nicholas Taleb', year: 2001),
  BookRef(title: 'The (Mis)Behaviour of Markets', author: 'Benoit Mandelbrot & Richard Hudson', year: 2004),

  // Sector & Cycle
  BookRef(title: 'The Alchemy of Finance', author: 'George Soros', year: 1987),
  BookRef(title: 'Capital Returns', author: 'Edward Chancellor', year: 2015),
  BookRef(title: 'The Investment Checklist', author: 'Michael Shearn', year: 2011),
  BookRef(title: 'Competition Demystified', author: 'Bruce Greenwald & Judd Kahn', year: 2005),
  BookRef(title: 'The Outsiders', author: 'William Thorndike', year: 2012),
  BookRef(title: 'Lessons from the Titans', author: 'Scott Davis, Carter Copeland & Rob Wertheimer', year: 2020),

  // Risk & Psychology
  BookRef(title: 'Thinking, Fast and Slow', author: 'Daniel Kahneman', year: 2011),
  BookRef(title: 'Against the Gods', author: 'Peter Bernstein', year: 1996),
  BookRef(title: 'The Black Swan', author: 'Nassim Nicholas Taleb', year: 2007),
  BookRef(title: 'When Genius Failed', author: 'Roger Lowenstein', year: 2000),
  BookRef(title: 'A Random Walk Down Wall Street', author: 'Burton Malkiel', year: 1973),
  BookRef(title: 'The Psychology of Money', author: 'Morgan Housel', year: 2020),
  BookRef(title: 'Behavioural Investing', author: 'James Montier', year: 2007),
  BookRef(title: 'The Little Book of Behavioural Investing', author: 'James Montier', year: 2010),

  // Macro & Markets
  BookRef(title: 'Manias, Panics and Crashes', author: 'Charles Kindleberger', year: 1978),
  BookRef(title: 'This Time Is Different', author: 'Carmen Reinhart & Kenneth Rogoff', year: 2009),
  BookRef(title: 'The Lords of Finance', author: 'Liaquat Ahamed', year: 2009),
  BookRef(title: 'Extraordinary Popular Delusions and the Madness of Crowds', author: 'Charles Mackay', year: 1841, gutenbergId: 24518),
  BookRef(title: 'How to Invest Money', author: 'George Garr Henry', year: 1908, gutenbergId: 34463),
  BookRef(title: 'Successful Stock Speculation', author: 'John James Butler', year: 1922, gutenbergId: 26841),
  BookRef(title: 'Everybody\u2019s Guide to Money Matters', author: 'William Cotton', year: 1898, gutenbergId: 1903),
  BookRef(title: 'The Theory of Stock Exchange Speculation', author: 'Arthur Crump', year: 1887, gutenbergId: 59518),
  BookRef(title: 'The Crowd: A Study of the Popular Mind', author: 'Gustave Le Bon', year: 1895, gutenbergId: 445),
  BookRef(title: 'The Wealth of Nations', author: 'Adam Smith', year: 1776, gutenbergId: 3300),
  BookRef(title: 'The General Theory of Employment, Interest and Money', author: 'John Maynard Keynes', year: 1936),
  BookRef(title: 'Principles for Navigating Big Debt Crises', author: 'Ray Dalio', year: 2018),
  BookRef(title: 'Stocks for the Long Run', author: 'Jeremy Siegel', year: 1994),
];

// ---------------------------------------------------------------------------
// Framework library
// ---------------------------------------------------------------------------

const List<BookFramework> kFrameworks = [
  BookFramework(
    id: 'magic-formula',
    name: 'Magic Formula',
    book: BookRef(title: 'The Little Book That Beats the Market', author: 'Joel Greenblatt', year: 2005),
    category: FrameworkCategory.value,
    philosophy:
        'Buy "good companies at cheap prices, on average". Rank the universe on two independent axes — how cheap '
        'it is and how good the business is — add the two ranks, and buy the lowest combined score. Discipline and '
        'diversification do the work, not stock-picking skill.',
    metrics: ['Earnings Yield = EBIT / Enterprise Value', 'Return on Capital = EBIT / (Net Fixed Assets + Working Capital)', 'Composite rank = EY rank + ROC rank'],
    criteria: [
      FrameworkCriterion(
        name: 'Earnings yield',
        description: 'EBIT divided by enterprise value; higher is cheaper.',
        metric: 'EBIT / EV',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'Top decile of the universe',
      ),
      FrameworkCriterion(
        name: 'Return on capital',
        description: 'EBIT divided by net fixed assets plus working capital; higher is better.',
        metric: 'EBIT / (Net Fixed Assets + Working Capital)',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'Top decile of the universe',
      ),
      FrameworkCriterion(
        name: 'Composite rank',
        description: 'Add the two percentile ranks; the lowest combined score is the best candidate.',
        metric: 'EY rank + ROC rank',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'Lowest combined rank',
      ),
      FrameworkCriterion(
        name: 'Exclusions',
        description: 'Financial and utility companies are excluded, as are foreign listings and micro caps.',
        metric: 'Sector and listing',
        kind: CriterionKind.market,
        computableFromCandles: false,
        threshold: 'Market cap above roughly \$50m; no financials or utilities',
      ),
    ],
    sources: [
      'Joel Greenblatt, "The Little Book That Beats the Market" (2005), criteria summarised on Wikipedia (Magic formula investing) and Investopedia.',
      'Forbes interview with Greenblatt (2010) describing earnings yield and return on capital.',
    ],
  ),

  BookFramework(
    id: 'canslim',
    name: 'CAN SLIM',
    book: BookRef(title: 'How to Make Money in Stocks', author: 'William J. O\u2019Neil', year: 1988),
    category: FrameworkCategory.growth,
    philosophy:
        'Winning stocks share seven traits before their biggest advances: accelerating quarterly earnings, annual '
        'growth, something new, supportive supply and demand, leadership within the group, institutional sponsorship, '
        'and a favourable market. Losses are cut at 7-8% without exception.',
    metrics: ['Quarterly EPS growth', 'Annual EPS growth and ROE', 'Relative strength percentile', 'Distance from 52-week high', 'Volume vs average'],
    criteria: [
      FrameworkCriterion(
        name: 'C — current quarterly earnings',
        description: 'Latest quarter EPS up sharply versus the same quarter a year earlier, and accelerating.',
        metric: 'Quarterly EPS growth, year over year',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'At least +20% to +25%, positive',
      ),
      FrameworkCriterion(
        name: 'A — annual earnings',
        description: 'Multi-year annual earnings growth with high return on equity.',
        metric: '3-year EPS growth; ROE',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: '3-year EPS growth 25% or more; ROE 17% or more',
      ),
      FrameworkCriterion(
        name: 'N — new highs',
        description: 'Something new, and price trading near its 52-week high rather than deep in a base.',
        metric: 'Distance from the 52-week high',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Within 15% of the 52-week high',
      ),
      FrameworkCriterion(
        name: 'S — supply and demand',
        description: 'Reasonable share count, buybacks, and volume expansion on the breakout.',
        metric: 'Volume versus its average',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Breakout volume above average',
      ),
      FrameworkCriterion(
        name: 'L — leader, not laggard',
        description: 'Relative price strength in the top of the market, not the bottom.',
        metric: '12-month relative strength percentile',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Percentile rank 80 or higher (70 minimum)',
      ),
      FrameworkCriterion(
        name: 'I — institutional sponsorship',
        description: 'Held by a growing number of institutional investors.',
        metric: 'Institutional ownership',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'At least 10 institutions, increasing',
      ),
      FrameworkCriterion(
        name: 'M — market direction',
        description: 'The general market should be in an uptrend; three of four stocks follow it.',
        metric: 'Index trend',
        kind: CriterionKind.market,
        computableFromCandles: false,
        threshold: 'Market in a confirmed uptrend',
      ),
      FrameworkCriterion(
        name: 'Loss limit',
        description: 'Cut every loss at 7-8% below the buy point, with no exceptions.',
        metric: 'Stop distance',
        kind: CriterionKind.risk,
        computableFromCandles: true,
        threshold: '7% to 8% maximum',
      ),
    ],
    sources: [
      'William O\u2019Neil, "How to Make Money in Stocks"; the seven factors are summarised on Wikipedia (CAN SLIM) and Investopedia.',
      'AAII screening model articles setting out the numeric thresholds used above.',
    ],
  ),

  BookFramework(
    id: 'minervini-trend-template',
    name: 'Trend Template (SEPA / VCP)',
    book: BookRef(title: 'Trade Like a Stock Market Wizard', author: 'Mark Minervini', year: 2013),
    category: FrameworkCategory.momentum,
    philosophy:
        'Only buy Stage 2 uptrends, confirmed mechanically by an eight-point trend template, and enter on a '
        'Volatility Contraction Pattern: a base of two to six pullbacks, each shallower than the last, on drying '
        'volume, breaking out through the pivot on expanding volume. Risk is pre-written before entry.',
    metrics: ['50/150/200-day moving-average stack', '200-day slope', 'Distance from 52-week high and low', 'Relative strength rating', 'Successive pullback depths', 'Volume dry-up'],
    criteria: [
      FrameworkCriterion(
        name: 'Price above the long averages',
        description: 'Price is above both the 150-day and the 200-day moving average.',
        metric: 'Price vs SMA150 and SMA200',
        kind: CriterionKind.technical,
        computableFromCandles: true,
      ),
      FrameworkCriterion(
        name: '150 above 200',
        description: 'The 150-day average sits above the 200-day average.',
        metric: 'SMA150 vs SMA200',
        kind: CriterionKind.technical,
        computableFromCandles: true,
      ),
      FrameworkCriterion(
        name: '200-day rising',
        description: 'The 200-day average is higher than it was 30 days ago.',
        metric: 'SMA200 slope over 30 bars',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Higher than 30 days ago',
      ),
      FrameworkCriterion(
        name: '50 above both',
        description: 'The 50-day average is above both the 150-day and the 200-day average.',
        metric: 'SMA50 vs SMA150 and SMA200',
        kind: CriterionKind.technical,
        computableFromCandles: true,
      ),
      FrameworkCriterion(
        name: 'Price above 50',
        description: 'Price is above the 50-day moving average.',
        metric: 'Price vs SMA50',
        kind: CriterionKind.technical,
        computableFromCandles: true,
      ),
      FrameworkCriterion(
        name: 'Well off the low',
        description: 'Price is at least 30% above its 52-week low.',
        metric: 'Distance above the 52-week low',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: '30% or more',
      ),
      FrameworkCriterion(
        name: 'Near the high',
        description: 'Price is within 25% of its 52-week high; closer is better.',
        metric: 'Distance below the 52-week high',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Within 25%',
      ),
      FrameworkCriterion(
        name: 'Relative strength',
        description: 'Relative strength rating against the broader market.',
        metric: 'RS percentile',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: '70 or higher, preferably 80-90',
      ),
      FrameworkCriterion(
        name: 'Volatility contraction',
        description: 'Two to six successive pullbacks, each shallower than the last, with volume drying up.',
        metric: 'Contraction sequence and volume trend',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Progressively shallower pullbacks on declining volume',
      ),
    ],
    sources: [
      'Mark Minervini, "Trade Like a Stock Market Wizard" — the eight-point Trend Template.',
      'Published breakdowns of the Trend Template and VCP criteria (TrendSpider, ChartMill, LuxAlgo).',
    ],
  ),

  BookFramework(
    id: 'graham-defensive',
    name: 'Defensive Investor',
    book: BookRef(title: 'The Intelligent Investor', author: 'Benjamin Graham', year: 1949),
    category: FrameworkCategory.value,
    philosophy:
        'The defensive investor buys sound, large, conservatively financed companies at moderate prices, diversifies '
        'across many issues, and refuses to overpay. Margin of safety — not forecasting — is the organising principle.',
    metrics: ['Earnings-to-price ratio', 'Price-to-book', 'Current ratio', 'Debt vs equity', 'Earnings stability'],
    criteria: [
      FrameworkCriterion(
        name: 'Adequate size',
        description: 'A sufficiently large, established company.',
        metric: 'Market capitalisation',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
      ),
      FrameworkCriterion(
        name: 'Strong financial condition',
        description: 'Current assets comfortably exceed current liabilities.',
        metric: 'Current ratio',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'Current ratio of 2 or more',
      ),
      FrameworkCriterion(
        name: 'Earnings stability',
        description: 'Positive earnings in each of the last several years.',
        metric: 'Years of positive earnings',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
      ),
      FrameworkCriterion(
        name: 'Moderate price relative to assets',
        description: 'Price is moderate relative to book value and earnings.',
        metric: 'P/E and P/B',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'P/E below 15, P/B below 1.5 (or P/E x P/B below 22.5)',
      ),
      FrameworkCriterion(
        name: 'Long-run trend',
        description: 'A modest but sustained increase in per-share earnings over a decade.',
        metric: '10-year EPS trend',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'At least a 33% increase over ten years',
      ),
    ],
    sources: [
      'Benjamin Graham, "The Intelligent Investor" — the defensive-investor criteria.',
      'Commonly reproduced summaries of Graham\u2019s seven defensive criteria.',
    ],
  ),

  BookFramework(
    id: 'lynch-peg',
    name: 'Growth at a Reasonable Price (PEG)',
    book: BookRef(title: 'One Up on Wall Street', author: 'Peter Lynch', year: 1989),
    category: FrameworkCategory.growth,
    philosophy:
        'Know what you own and why. Sort companies into six categories (slow growers, stalwarts, fast growers, '
        'cyclicals, turnarounds, asset plays) and judge each by its own yardstick. A fair price for growth is a '
        'PEG near or below one.',
    metrics: ['PEG = P/E divided by growth rate', 'Debt-to-equity', 'Inventory trend', 'Free cash flow'],
    criteria: [
      FrameworkCriterion(
        name: 'PEG ratio',
        description: 'The price-to-earnings ratio divided by the earnings growth rate.',
        metric: 'PEG',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'Below 1.0 is attractive; below 0.5 is very cheap',
      ),
      FrameworkCriterion(
        name: 'Balance-sheet strength',
        description: 'Low debt relative to equity, especially for cyclicals and turnarounds.',
        metric: 'Debt / equity',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
        threshold: 'Conservative',
      ),
      FrameworkCriterion(
        name: 'Understandable business',
        description: 'You can explain the business and its earnings driver in one sentence.',
        metric: 'Qualitative',
        kind: CriterionKind.market,
        computableFromCandles: false,
      ),
    ],
    sources: [
      'Peter Lynch, "One Up on Wall Street" — the six company categories and the PEG yardstick.',
    ],
  ),

  BookFramework(
    id: 'piotroski-fscore',
    name: 'Piotroski F-Score',
    book: BookRef(title: 'Value Investing: The Use of Historical Financial Statement Information', author: 'Joseph Piotroski', year: 2000),
    category: FrameworkCategory.factor,
    philosophy:
        'A nine-point fundamental score that separates improving firms from deteriorating ones within the cheap '
        'universe. Each test is a simple binary signal; the score is the sum.',
    metrics: ['ROA', 'Operating cash flow', 'Leverage', 'Current ratio', 'Gross margin', 'Asset turnover'],
    criteria: [
      FrameworkCriterion(
        name: 'Profitability tests',
        description: 'Positive ROA, positive operating cash flow, rising ROA, and cash flow above net income.',
        metric: 'ROA and CFO',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
      ),
      FrameworkCriterion(
        name: 'Leverage, liquidity, source of funds',
        description: 'Falling long-term debt, rising current ratio, and no new share issuance.',
        metric: 'Debt, current ratio, share count',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
      ),
      FrameworkCriterion(
        name: 'Operating efficiency',
        description: 'Rising gross margin and rising asset turnover.',
        metric: 'Gross margin, asset turnover',
        kind: CriterionKind.fundamental,
        computableFromCandles: false,
      ),
    ],
    sources: [
      'Joseph Piotroski, "Value Investing: The Use of Historical Financial Statement Information" (2000).',
    ],
  ),

  BookFramework(
    id: 'weinstein-stage',
    name: 'Stage Analysis',
    book: BookRef(title: 'Secrets for Profiting in Bull and Bear Markets', author: 'Stan Weinstein', year: 1988),
    category: FrameworkCategory.sector,
    philosophy:
        'Every market and stock moves through four stages: basing, advancing, topping, declining. Trade only Stage 2, '
        'and only with the 30-week moving average rising and price above it.',
    metrics: ['30-week (150-day) moving average', 'Price relative to the average', 'Volume on the breakout'],
    criteria: [
      FrameworkCriterion(
        name: 'Stage 2 confirmation',
        description: 'Price above a rising 30-week moving average, making higher highs and higher lows.',
        metric: 'Price vs SMA150, SMA150 slope',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Price above a rising 30-week average',
      ),
      FrameworkCriterion(
        name: 'Breakout volume',
        description: 'The move out of the base comes on clearly above-average volume.',
        metric: 'Volume versus average',
        kind: CriterionKind.technical,
        computableFromCandles: true,
      ),
      FrameworkCriterion(
        name: 'Relative strength',
        description: 'The stock outperforms the market index.',
        metric: 'Relative strength vs index',
        kind: CriterionKind.technical,
        computableFromCandles: true,
      ),
    ],
    sources: [
      'Stan Weinstein, "Secrets for Profiting in Bull and Bear Markets" — four-stage analysis.',
    ],
  ),

  BookFramework(
    id: 'momentum-factor',
    name: 'Cross-Sectional Momentum',
    book: BookRef(title: 'Returns to Buying Winners and Selling Losers', author: 'Jegadeesh & Titman', year: 1993),
    category: FrameworkCategory.factor,
    philosophy:
        'Stocks that outperformed over the past 3-12 months tend to keep outperforming over the next 1-12 months, '
        'and losers keep losing. The effect is cross-sectional: it is the ranking against peers that carries the signal.',
    metrics: ['12-month return excluding the most recent month', 'Cross-sectional rank', 'Volatility scaling'],
    criteria: [
      FrameworkCriterion(
        name: 'Trailing momentum',
        description: 'Strong return over the formation window, skipping the most recent month.',
        metric: '12-1 month return',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Top decile of the universe',
      ),
      FrameworkCriterion(
        name: 'Cross-sectional rank',
        description: 'Ranked against the full universe, not judged in isolation.',
        metric: 'Momentum percentile',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Top decile',
      ),
      FrameworkCriterion(
        name: 'Volatility awareness',
        description: 'Momentum portfolios carry crash risk; scale or filter by volatility.',
        metric: 'Realised volatility',
        kind: CriterionKind.risk,
        computableFromCandles: true,
      ),
    ],
    sources: [
      'Jegadeesh & Titman, "Returns to Buying Winners and Selling Losers" (Journal of Finance, 1993).',
      'Factor-investing literature summarising the momentum premium.',
    ],
  ),

  BookFramework(
    id: 'turtle-trend',
    name: 'Turtle Trend Following',
    book: BookRef(title: 'Way of the Turtle', author: 'Curtis Faith', year: 2007),
    category: FrameworkCategory.momentum,
    philosophy:
        'Trade breakouts to new highs, size positions from volatility so each unit risks the same amount, and let '
        'the trend run while cutting losers quickly. The edge is in the system and the discipline, not the forecast.',
    metrics: ['N-day breakout level', 'Average true range (volatility unit)', 'Position size from ATR'],
    criteria: [
      FrameworkCriterion(
        name: 'Breakout entry',
        description: 'Price exceeds its highest high of the prior N days.',
        metric: 'N-day high breakout',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: '20-day or 55-day breakout',
      ),
      FrameworkCriterion(
        name: 'Volatility sizing',
        description: 'Position size is derived from the ATR so each trade risks a fixed fraction of equity.',
        metric: 'ATR',
        kind: CriterionKind.risk,
        computableFromCandles: true,
        threshold: 'Risk 1-2% of equity per unit',
      ),
      FrameworkCriterion(
        name: 'Trend filter',
        description: 'Only take longs when the longer-term trend is up.',
        metric: 'Price vs long moving average',
        kind: CriterionKind.technical,
        computableFromCandles: true,
      ),
    ],
    sources: [
      'Curtis Faith, "Way of the Turtle"; the Turtle rules are widely documented.',
    ],
  ),

  BookFramework(
    id: 'low-volatility',
    name: 'Low-Volatility / Quality Screen',
    book: BookRef(title: 'Your Complete Guide to Factor-Based Investing', author: 'Andrew Berkin & Larry Swedroe', year: 2016),
    category: FrameworkCategory.factor,
    philosophy:
        'Lower-volatility, higher-quality stocks have historically delivered better risk-adjusted returns than the '
        'market, contrary to the assumption that risk and return must rise together. Combine the low-volatility and '
        'quality factors and rebalance patiently.',
    metrics: ['Realised volatility', 'Drawdown depth', 'Return consistency', 'Balance-sheet quality'],
    criteria: [
      FrameworkCriterion(
        name: 'Low realised volatility',
        description: 'Trailing volatility below the universe median.',
        metric: 'Annualised volatility',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Bottom third of the universe',
      ),
      FrameworkCriterion(
        name: 'Shallow drawdowns',
        description: 'Historically smaller peak-to-trough declines than peers.',
        metric: 'Maximum drawdown',
        kind: CriterionKind.risk,
        computableFromCandles: true,
      ),
      FrameworkCriterion(
        name: 'Return consistency',
        description: 'A higher proportion of up-periods than the universe.',
        metric: 'Share of positive periods',
        kind: CriterionKind.technical,
        computableFromCandles: true,
      ),
    ],
    sources: [
      'Berkin & Swedroe, "Your Complete Guide to Factor-Based Investing" — the low-volatility and quality factors.',
      'CFA Institute Research Foundation material on factor investing.',
    ],
  ),

  BookFramework(
    id: 'wilder-rsi-atr',
    name: 'RSI & Volatility Units',
    book: BookRef(title: 'New Concepts in Technical Trading Systems', author: 'J. Welles Wilder Jr.', year: 1978),
    category: FrameworkCategory.momentum,
    philosophy:
        'Introduces the Relative Strength Index, Average True Range and the parabolic stop-and-reverse. RSI measures '
        'the ratio of average gains to average losses over a lookback; ATR provides a volatility unit used to size '
        'positions and place stops consistently across instruments.',
    metrics: ['RSI(14)', 'Average True Range', 'Directional movement'],
    criteria: [
      FrameworkCriterion(
        name: 'RSI oversold',
        description: 'RSI(14) below the oversold threshold, used as a mean-reversion entry.',
        metric: 'RSI(14)',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Below 30',
      ),
      FrameworkCriterion(
        name: 'RSI overbought',
        description: 'RSI(14) above the overbought threshold, used as the exit.',
        metric: 'RSI(14)',
        kind: CriterionKind.technical,
        computableFromCandles: true,
        threshold: 'Above 70',
      ),
      FrameworkCriterion(
        name: 'Volatility unit',
        description: 'Average True Range defines the size of one risk unit.',
        metric: 'ATR',
        kind: CriterionKind.risk,
        computableFromCandles: true,
        threshold: 'Stops and sizing expressed in ATR multiples',
      ),
    ],
    sources: [
      'J. Welles Wilder Jr., "New Concepts in Technical Trading Systems" (1978) — RSI, ATR and directional movement.',
    ],
  ),
];

/// Look a framework up by id.
BookFramework? frameworkById(String id) {
  for (final f in kFrameworks) {
    if (f.id == id) return f;
  }
  return null;
}

/// The public-domain subset of the catalogue, which the app may fetch legally.
List<BookRef> publicDomainBooks() =>
    kBookCatalogue.where((b) => b.isPublicDomain).toList(growable: false);
