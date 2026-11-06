/// Common Indian foods with approximate values for a typical home portion.
/// Real values vary with recipe, oil and size, so show them as approximate.
class FoodPreset {
  final String name;
  final String serving;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const FoodPreset(this.name, this.serving, this.kcal, this.protein, this.carbs, this.fat);
}

const indianFoods = <FoodPreset>[
  FoodPreset('Roti / chapati', '1 medium', 105, 3.5, 20, 1),
  FoodPreset('Paratha (plain)', '1 medium', 230, 4.5, 30, 10),
  FoodPreset('Steamed rice', '1 katori (150 g)', 195, 4, 43, 0.4),
  FoodPreset('Dal (tadka)', '1 katori (150 g)', 150, 8, 22, 3),
  FoodPreset('Rajma curry', '1 katori (150 g)', 190, 9, 28, 4),
  FoodPreset('Chole', '1 katori (150 g)', 210, 9, 28, 7),
  FoodPreset('Khichdi', '1 katori (150 g)', 160, 6, 28, 3),
  FoodPreset('Mixed veg sabzi', '1 katori (120 g)', 110, 3, 12, 6),
  FoodPreset('Aloo sabzi', '1 katori (120 g)', 160, 3, 24, 6),
  FoodPreset('Paneer bhurji', '1 katori (100 g)', 250, 14, 5, 19),
  FoodPreset('Chicken curry', '1 katori (150 g)', 240, 22, 5, 14),
  FoodPreset('Chicken biryani', '1 plate (300 g)', 450, 22, 55, 15),
  FoodPreset('Curd / dahi', '1 katori (100 g)', 60, 3.5, 5, 3),
  FoodPreset('Boiled egg', '1 egg', 78, 6, 0.6, 5),
  FoodPreset('Omelette', '2 eggs', 190, 13, 1.5, 15),
  FoodPreset('Idli', '1 piece', 40, 1.5, 8, 0.2),
  FoodPreset('Dosa (plain)', '1 medium', 135, 3, 25, 3),
  FoodPreset('Sambar', '1 katori (150 g)', 90, 4, 14, 2),
  FoodPreset('Poha', '1 plate (150 g)', 250, 5, 45, 6),
  FoodPreset('Upma', '1 plate (150 g)', 230, 5, 35, 8),
  FoodPreset('Samosa', '1 piece', 260, 4, 28, 15),
  FoodPreset('Banana', '1 medium', 105, 1.3, 27, 0.4),
  FoodPreset('Apple', '1 medium', 95, 0.5, 25, 0.3),
  FoodPreset('Milk (toned)', '1 glass (200 ml)', 120, 6.5, 10, 6),
  FoodPreset('Tea with milk and sugar', '1 cup', 60, 1.5, 9, 2),
  FoodPreset('Almonds', '10 pieces', 70, 2.5, 2.5, 6),
  FoodPreset('Whey protein', '1 scoop (30 g)', 120, 24, 3, 1.5),
  FoodPreset('Moong dal chilla', '1 piece', 110, 7, 13, 3),
  FoodPreset('Besan chilla', '1 piece', 120, 6, 14, 4),
  FoodPreset('Sprouts salad', '1 katori (100 g)', 90, 7, 14, 1),
  FoodPreset('Paneer (cooked, curry)', '1 katori (100 g)', 270, 14, 6, 21),
  FoodPreset('Paneer tikka', '4 pieces (100 g)', 230, 15, 5, 16),
  FoodPreset('Soya chunks curry', '1 katori (120 g)', 170, 17, 12, 5),
  FoodPreset('Chicken tikka', '4 pieces (120 g)', 200, 26, 4, 8),
  FoodPreset('Grilled fish', '1 piece (120 g)', 190, 24, 0, 10),
  FoodPreset('Fish curry', '1 katori (150 g)', 220, 20, 6, 13),
  FoodPreset('Egg curry', '1 katori (150 g)', 230, 13, 8, 16),
  FoodPreset('Egg bhurji', '2 eggs', 200, 13, 3, 15),
  FoodPreset('Masoor / moong dal (plain)', '1 katori (150 g)', 130, 8, 20, 2),
  FoodPreset('Palak paneer', '1 katori (150 g)', 260, 13, 9, 19),
  FoodPreset('Bhindi sabzi', '1 katori (100 g)', 100, 2, 9, 6),
  FoodPreset('Gobi sabzi', '1 katori (100 g)', 90, 3, 9, 5),
  FoodPreset('Jeera rice', '1 katori (150 g)', 220, 4, 40, 5),
  FoodPreset('Brown rice', '1 katori (150 g)', 165, 4, 34, 1.3),
  FoodPreset('Bajra / jowar roti', '1 medium', 95, 3, 18, 1),
  FoodPreset('Methi thepla', '1 piece', 130, 3.5, 17, 5),
  FoodPreset('Aloo paratha', '1 medium', 290, 6, 40, 11),
  FoodPreset('Pav bhaji', '1 plate (2 pav)', 400, 9, 55, 16),
  FoodPreset('Vada pav', '1 piece', 290, 6, 40, 12),
  FoodPreset('Masala dosa', '1 medium', 250, 5, 35, 10),
  FoodPreset('Uttapam', '1 medium', 190, 5, 30, 5),
  FoodPreset('Oats (with milk)', '1 bowl (200 g)', 220, 9, 32, 6),
  FoodPreset('Dalia / daliya', '1 bowl (150 g)', 170, 5, 32, 2),
  FoodPreset('Lassi (sweet)', '1 glass (250 ml)', 190, 6, 28, 5),
  FoodPreset('Buttermilk / chaas', '1 glass (200 ml)', 40, 2, 4, 1.5),
  FoodPreset('Coconut water', '1 glass (200 ml)', 45, 0.5, 10, 0.2),
  FoodPreset('Roasted chana', '1 handful (30 g)', 110, 6, 17, 1.5),
  FoodPreset('Peanuts (roasted)', '1 handful (30 g)', 170, 8, 5, 14),
  FoodPreset('Makhana (roasted)', '1 bowl (30 g)', 105, 3, 22, 0.5),
  FoodPreset('Gulab jamun', '1 piece', 150, 2, 22, 6),
  FoodPreset('Orange', '1 medium', 62, 1.2, 15, 0.2),
  FoodPreset('Papaya', '1 bowl (150 g)', 65, 0.7, 16, 0.2),
];
