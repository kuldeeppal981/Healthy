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
];
