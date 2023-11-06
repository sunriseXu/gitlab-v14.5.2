export const day1 = {
  date: '2020-08-08',
  completedCount: 0,
  completedWeight: 0,
  scopeCount: 10,
  scopeWeight: 20,
};

export const day2 = {
  date: '2020-08-09',
  completedCount: 1,
  completedWeight: 1,
  scopeCount: 11,
  scopeWeight: 20,
};

export const day3 = {
  date: '2020-08-10',
  completedCount: 2,
  completedWeight: 4,
  scopeCount: 11,
  scopeWeight: 22,
};

export const day4 = {
  date: '2020-08-11',
  completedCount: 3,
  completedWeight: 5,
  scopeCount: 11,
  scopeWeight: 22,
};

export const legacyBurndownEvents = [
  {
    action: 'created',
    created_at: day1.date,
    weight: 2,
  },
  {
    action: 'created',
    created_at: day2.date,
    weight: 1,
  },
  {
    action: 'created',
    created_at: day3.date,
    weight: 1,
  },
  {
    action: 'closed',
    created_at: day4.date,
    weight: 2,
  },
];
