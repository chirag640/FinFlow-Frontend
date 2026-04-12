import '../../domain/entities/expense_category.dart';

class ExpenseCategorySuggestionService {
  static final Map<ExpenseCategory, List<String>> _keywords = {
    ExpenseCategory.food: [
      'food',
      'restaurant',
      'cafe',
      'coffee',
      'dinner',
      'lunch',
      'breakfast',
      'zomato',
      'swiggy',
      'uber eats',
    ],
    ExpenseCategory.groceries: [
      'grocery',
      'groceries',
      'supermarket',
      'mart',
      'bigbasket',
      'blinkit',
      'zepto',
      'milk',
      'vegetable',
    ],
    ExpenseCategory.transport: [
      'uber',
      'ola',
      'taxi',
      'cab',
      'bus',
      'metro',
      'fuel',
      'petrol',
      'diesel',
      'parking',
      'toll',
    ],
    ExpenseCategory.shopping: [
      'shopping',
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'mall',
      'clothes',
      'fashion',
    ],
    ExpenseCategory.entertainment: [
      'movie',
      'netflix',
      'spotify',
      'prime video',
      'game',
      'gaming',
      'bookmyshow',
      'concert',
    ],
    ExpenseCategory.bills: [
      'bill',
      'electricity',
      'water',
      'gas',
      'internet',
      'wifi',
      'broadband',
      'mobile recharge',
      'phone bill',
      'dth',
      'utility',
    ],
    ExpenseCategory.subscriptions: [
      'subscription',
      'monthly plan',
      'yearly plan',
      'renewal',
      'saas',
      'icloud',
      'youtube premium',
      'chatgpt',
      'canva',
      'notion',
    ],
    ExpenseCategory.rent: [
      'rent',
      'landlord',
      'maintenance',
      'society',
      'housing',
      'lease',
      'emi',
      'mortgage',
    ],
    ExpenseCategory.health: [
      'hospital',
      'doctor',
      'clinic',
      'pharmacy',
      'medicine',
      'medicines',
      'lab test',
      'health',
      'insurance',
    ],
    ExpenseCategory.education: [
      'school',
      'college',
      'course',
      'tuition',
      'udemy',
      'coursera',
      'book',
      'exam',
    ],
    ExpenseCategory.travel: [
      'flight',
      'hotel',
      'airbnb',
      'trip',
      'travel',
      'train',
      'holiday',
      'vacation',
      'booking',
    ],
  };

  static ExpenseCategory? infer(String description) {
    final text = description.trim().toLowerCase();
    if (text.length < 3) return null;

    ExpenseCategory? bestCategory;
    var bestScore = 0;

    for (final entry in _keywords.entries) {
      var score = 0;
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          score += keyword.length;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestCategory = entry.key;
      }
    }

    return bestScore == 0 ? null : bestCategory;
  }

  static bool isBillLike(ExpenseCategory category) {
    return category == ExpenseCategory.bills ||
        category == ExpenseCategory.subscriptions ||
        category == ExpenseCategory.rent;
  }
}
