/// Foods used by the budget diet planner.
///
/// Prices are rough home-cooking costs in rupees for one serving in a typical
/// Indian city. They change by city and season, so the app shows them as
/// approximate and lets the user pick a cheaper or costlier price level.
class PlanFood {
  final String name;
  final String serving;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double price; // rupees per serving
  final String diet; // veg | egg | nonveg
  final String role; // staple | main | side | snack
  final List<String> slots; // breakfast | lunch | snacks | dinner
  final List<String> allergens; // ids from allergy_checker.dart
  final double maxServ;

  const PlanFood(
    this.name,
    this.serving,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.price,
    this.diet,
    this.role,
    this.slots,
    this.allergens, {
    this.maxServ = 2,
  });
}

const _b = ['breakfast'];
const _ld = ['lunch', 'dinner'];
const _s = ['snacks'];
const _bs = ['breakfast', 'snacks'];
const _all = ['breakfast', 'lunch', 'snacks', 'dinner'];

const planFoods = <PlanFood>[
  // Breakfast mains
  PlanFood('Poha', '1 plate', 250, 5, 45, 6, 15, 'veg', 'main', _b, ['peanut']),
  PlanFood('Upma', '1 plate', 230, 5, 35, 8, 14, 'veg', 'main', _b, ['gluten']),
  PlanFood('Idli', '1 piece', 40, 1.5, 8, 0.2, 4, 'veg', 'main', _b, [], maxServ: 6),
  PlanFood('Dosa (plain)', '1 medium', 135, 3, 25, 3, 10, 'veg', 'main', _b, [], maxServ: 3),
  PlanFood('Besan chilla', '1 piece', 140, 7, 15, 6, 8, 'veg', 'main', _b, [], maxServ: 3),
  PlanFood('Moong dal chilla', '1 piece', 130, 8, 14, 4, 10, 'veg', 'main', _b, [], maxServ: 3),
  PlanFood('Oats with milk', '1 bowl', 220, 9, 32, 6, 20, 'veg', 'main', _b, ['gluten', 'milk']),
  PlanFood('Daliya porridge', '1 bowl', 180, 6, 34, 2, 10, 'veg', 'main', _b, ['gluten']),
  PlanFood('Paratha (plain)', '1 medium', 230, 4.5, 30, 10, 10, 'veg', 'main', _b, ['gluten']),
  PlanFood('Omelette', '2 eggs', 190, 13, 1.5, 15, 18, 'egg', 'main', _b, ['egg']),
  // Breakfast / snack sides
  PlanFood('Sambar', '1 katori', 90, 4, 14, 2, 8, 'veg', 'side', _b, []),
  PlanFood('Boiled egg', '1 egg', 78, 6, 0.6, 5, 8, 'egg', 'side', _bs, ['egg'], maxServ: 3),
  PlanFood('Curd / dahi', '1 katori', 60, 3.5, 5, 3, 10, 'veg', 'side', _all, ['milk']),
  PlanFood('Milk (toned)', '1 glass', 120, 6.5, 10, 6, 14, 'veg', 'side', _bs, ['milk']),
  PlanFood('Banana', '1 medium', 105, 1.3, 27, 0.4, 6, 'veg', 'side', _bs, [], maxServ: 3),
  PlanFood('Sattu drink', '1 glass', 150, 8, 25, 2.5, 8, 'veg', 'side', _bs, ['gluten']),
  // Lunch / dinner staples
  PlanFood('Roti / chapati', '1 medium', 105, 3.5, 20, 1, 3, 'veg', 'staple', _ld, ['gluten'], maxServ: 5),
  PlanFood('Steamed rice', '1 katori', 195, 4, 43, 0.4, 8, 'veg', 'staple', _ld, [], maxServ: 2),
  PlanFood('Khichdi', '1 katori', 160, 6, 28, 3, 10, 'veg', 'staple', _ld, [], maxServ: 2),
  // Lunch / dinner mains
  PlanFood('Dal (tadka)', '1 katori', 150, 8, 22, 3, 12, 'veg', 'main', _ld, []),
  PlanFood('Rajma curry', '1 katori', 190, 9, 28, 4, 18, 'veg', 'main', _ld, []),
  PlanFood('Chole', '1 katori', 210, 9, 28, 7, 20, 'veg', 'main', _ld, []),
  PlanFood('Soya chunks curry', '1 katori', 170, 18, 10, 5, 16, 'veg', 'main', _ld, ['soy']),
  PlanFood('Paneer bhurji', '1 katori', 250, 14, 5, 19, 45, 'veg', 'main', _ld, ['milk'], maxServ: 1.5),
  PlanFood('Egg curry', '2 eggs', 220, 13, 6, 16, 25, 'egg', 'main', _ld, ['egg'], maxServ: 1.5),
  PlanFood('Chicken curry', '1 katori', 240, 22, 5, 14, 55, 'nonveg', 'main', _ld, [], maxServ: 1.5),
  PlanFood('Fish curry', '1 katori', 190, 20, 4, 10, 60, 'nonveg', 'main', _ld, ['fish'], maxServ: 1.5),
  // Lunch / dinner sides
  PlanFood('Mixed veg sabzi', '1 katori', 110, 3, 12, 6, 14, 'veg', 'side', _ld, [], maxServ: 1.5),
  PlanFood('Aloo sabzi', '1 katori', 160, 3, 24, 6, 10, 'veg', 'side', _ld, [], maxServ: 1.5),
  PlanFood('Cucumber tomato salad', '1 bowl', 30, 1, 6, 0.2, 8, 'veg', 'side', _ld, [], maxServ: 1.5),
  PlanFood('Sprouts salad', '1 bowl', 120, 9, 18, 1, 10, 'veg', 'side', ['lunch', 'dinner', 'snacks'], [], maxServ: 1.5),
  // Snacks
  PlanFood('Roasted chana', '30 g', 110, 6, 18, 2, 6, 'veg', 'snack', _s, [], maxServ: 2),
  PlanFood('Roasted peanuts', '30 g', 170, 7, 5, 14, 6, 'veg', 'snack', _s, ['peanut'], maxServ: 2),
  PlanFood('Makhana (roasted)', '30 g', 105, 3.5, 21, 0.5, 15, 'veg', 'snack', _s, [], maxServ: 2),
  PlanFood('Apple', '1 medium', 95, 0.5, 25, 0.3, 20, 'veg', 'snack', _s, []),
  PlanFood('Buttermilk', '1 glass', 40, 2, 3, 1.5, 5, 'veg', 'snack', _s, ['milk'], maxServ: 2),
  PlanFood('Tea with milk and sugar', '1 cup', 60, 1.5, 9, 2, 5, 'veg', 'snack', _s, ['milk']),
];
