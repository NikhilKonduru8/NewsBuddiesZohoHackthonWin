import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

void main() {
  runApp(NewsBuddiesApp());
}

class NewsBuddiesApp extends StatelessWidget {
  const NewsBuddiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewsBuddies',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF2E7D96),
        scaffoldBackgroundColor: Color(0xFFF8FAFC),
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String _childAge = '';
  List<String> _selectedCategories = [];
  String _customPrompt = ''; // ADDED: This was missing in the original code
  List<ArticleSummary> _articles = [];
  List<ReadingActivity> _activities = [];

  final String _newsApiKey = "API_KEY";
  final String _ollamaBaseUrl = "http://10.0.2.2:11434";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          KidsDashboard(
            articles: _articles,
            childAge: _childAge,
            selectedCategories: _selectedCategories,
            customPrompt:
                _customPrompt, // ADDED: Pass custom prompt to KidsDashboard
            onAgeSet: (age) => setState(() => _childAge = age),
            onCategoriesSet: (categories) {
              setState(() {
                _selectedCategories = categories;
                _customPrompt = ''; // ADD THIS LINE TO CLEAR THE CUSTOM PROMPT
                _articles = [];
              });
            },
            onCustomPromptSet: (prompt) {
              // ADDED: Handler for custom prompt
              setState(() {
                _customPrompt = prompt;
                _selectedCategories = ['Custom'];
                _articles = [];
              });
            },
            onArticlesLoaded: (articles) =>
                setState(() => _articles = articles),
            onActivityRecorded: _recordActivity,
            newsApiKey: _newsApiKey,
            ollamaBaseUrl: _ollamaBaseUrl,
          ),
          ParentLoginScreen(
            activities: _activities,
            articles: _articles,
            ollamaBaseUrl: _ollamaBaseUrl,
            key: ValueKey(_currentIndex),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Color(0xFF2E7D96),
          unselectedItemColor: Colors.grey[600],
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Kids Zone',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: 'Parent Zone',
            ),
          ],
        ),
      ),
    );
  }

  void _recordActivity(String articleTitle, String action) {
    setState(() {
      _activities.add(
        ReadingActivity(
          articleTitle: articleTitle,
          action: action,
          timestamp: DateTime.now(),
        ),
      );
    });
  }
}

class KidsDashboard extends StatefulWidget {
  final List<ArticleSummary> articles;
  final String childAge;
  final List<String> selectedCategories;
  final String customPrompt; // ADDED: Custom prompt parameter
  final Function(String) onAgeSet;
  final Function(List<String>) onCategoriesSet;
  final Function(String) onCustomPromptSet; // ADDED: Custom prompt setter
  final Function(List<ArticleSummary>) onArticlesLoaded;
  final Function(String, String) onActivityRecorded;
  final String newsApiKey;
  final String ollamaBaseUrl;

  KidsDashboard({
    required this.articles,
    required this.childAge,
    required this.selectedCategories,
    required this.customPrompt, // ADDED: Required custom prompt
    required this.onAgeSet,
    required this.onCategoriesSet,
    required this.onCustomPromptSet, // ADDED: Required custom prompt setter
    required this.onArticlesLoaded,
    required this.onActivityRecorded,
    required this.newsApiKey,
    required this.ollamaBaseUrl,
  });

  @override
  _KidsDashboardState createState() => _KidsDashboardState();
}

class _KidsDashboardState extends State<KidsDashboard> {
  final TextEditingController _ageController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String _statusMessage = '';
  bool _ollamaAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkOllamaAvailability();
  }

  Future<void> _checkOllamaAvailability() async {
    try {
      final response = await http
          .get(Uri.parse('${widget.ollamaBaseUrl}/api/tags'))
          .timeout(Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = data['models'] as List<dynamic>;
        _ollamaAvailable = models.any(
          (model) => model['name'].toString().contains('llama3.2'),
        );
      }
    } catch (e) {
      _ollamaAvailable = false;
    }
  }

  @override
  void didUpdateWidget(KidsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedCategories != widget.selectedCategories &&
        widget.selectedCategories.isNotEmpty &&
        widget.articles.isEmpty &&
        !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNews();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.childAge.isEmpty) {
      return _buildWelcomeScreen();
    }

    if (widget.selectedCategories.isEmpty) {
      return CategoriesSelectionScreen(
        childAge: widget.childAge,
        onCategoriesSelected: (categories) {
          widget.onCategoriesSet(categories);
        },
        onCustomPromptSelected: (prompt) {
          widget.onCustomPromptSet(prompt);
        },
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: widget.articles.isEmpty
                  ? _buildEmptyState()
                  : _buildArticleGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E7D96), Color(0xFF4A90A4)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.newspaper, size: 80, color: Colors.white),
              SizedBox(height: 24),
              Text(
                'NewsBuddies',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'News For Kids',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 48),
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'How old are you?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D96),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter your age',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF2E7D96)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startJourney,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D96),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Start Reading!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.newspaper, size: 32, color: Color(0xFF2E7D96)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NewsBuddies',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D96),
                      ),
                    ),
                    Text(
                      'Age: ${widget.childAge}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        widget.onArticlesLoaded([]);
                        widget.onCategoriesSet(
                          [],
                        ); // This will now clear both categories AND custom prompt
                      },
                      icon: Icon(Icons.interests, color: Color(0xFF2E7D96)),
                      tooltip: 'Change Topics',
                    ),
                    IconButton(
                      onPressed: _loadNews,
                      icon: Icon(Icons.refresh, color: Color(0xFF2E7D96)),
                      tooltip: 'Load New Stories',
                    ),
                  ],
                ),
            ],
          ),
          if (widget.customPrompt.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: Colors.purple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Custom: ${widget.customPrompt}',
                      style: TextStyle(
                        color: Colors.purple,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (widget.selectedCategories.isNotEmpty &&
              !widget.selectedCategories.contains('Custom')) ...[
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedCategories.map((category) {
                IconData icon = Icons.category;
                Color color = Colors.blue;

                switch (category) {
                  case 'Animals & Nature':
                    icon = Icons.pets;
                    color = Colors.green;
                    break;
                  case 'Science & Space':
                    icon = Icons.science;
                    color = Colors.blue;
                    break;
                  case 'Sports':
                    icon = Icons.sports_soccer;
                    color = Colors.orange;
                    break;
                  case 'Technology & Gaming':
                    icon = Icons.videogame_asset;
                    color = Colors.purple;
                    break;
                  case 'Arts & Music & Movies':
                    icon = Icons.palette;
                    color = Colors.pink;
                    break;
                  case 'Environment':
                    icon = Icons.eco;
                    color = Colors.teal;
                    break;
                  case 'Adventure & Travel':
                    icon = Icons.explore;
                    color = Colors.indigo;
                    break;
                  case 'Food & Cooking':
                    icon = Icons.restaurant;
                    color = Colors.amber;
                    break;
                }

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      SizedBox(width: 4),
                      Text(
                        category,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 24),
          Text(
            'No stories yet!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _loadNews,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2E7D96),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isLoading ? 'Loading Stories...' : 'Load Stories',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          if (_statusMessage.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
          if (_errorMessage.isNotEmpty) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArticleGrid() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisSpacing: 16,
          childAspectRatio: 2.8,
        ),
        itemCount: widget.articles.length,
        itemBuilder: (context, index) {
          return _buildArticleCard(widget.articles[index]);
        },
      ),
    );
  }

  Widget _buildArticleCard(ArticleSummary article) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openArticle(article),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 2,
                child: Text(
                  article.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D96),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 8),
              Flexible(
                flex: 3,
                child: Text(
                  article.summary.length > 150
                      ? '${article.summary.substring(0, 150)}...'
                      : article.summary,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF2E7D96).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Tap to Read',
                      style: TextStyle(
                        color: Color(0xFF2E7D96),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Spacer(),
                  if (article.wasScraped)
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startJourney() {
    if (_ageController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your age';
      });
      return;
    }

    final age = int.tryParse(_ageController.text);
    if (age == null || age < 3 || age > 18) {
      setState(() {
        _errorMessage = 'Please enter an age between 3 and 18';
      });
      return;
    }

    widget.onAgeSet(_ageController.text);
    setState(() {
      _errorMessage = '';
    });
  }

  void _openArticle(ArticleSummary article) {
    widget.onActivityRecorded(article.title, 'opened');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          ollamaBaseUrl: widget.ollamaBaseUrl,
          onLike: () => widget.onActivityRecorded(article.title, 'liked'),
        ),
      ),
    );
  }

  Future<void> _loadNews() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _statusMessage = 'Fetching latest stories...';
    });

    try {
      // Fetch articles in parallel with summary generation
      final articlesFuture = _fetchNewsArticles(4);

      final articles = await articlesFuture;

      if (articles.isEmpty) {
        throw Exception('No articles found');
      }

      // Process articles in parallel for faster loading
      List<Future<ArticleSummary>> summaryFutures = [];

      for (int i = 0; i < articles.length && i < 4; i++) {
        summaryFutures.add(_processArticle(articles[i], i));
      }

      // Wait for all summaries to complete
      List<ArticleSummary> summaries = await Future.wait(summaryFutures);

      widget.onArticlesLoaded(summaries);
      setState(() {
        _statusMessage = '';
        _errorMessage = '';
      });
    } catch (e) {
      print('Error loading news: $e');
      setState(() {
        _errorMessage = 'Failed to load stories: ${e.toString()}';
        _statusMessage = '';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<ArticleSummary> _processArticle(
    Map<String, dynamic> article,
    int index,
  ) async {
    setState(() {
      _statusMessage = 'Processing story ${index + 1}...';
    });

    String fullContent = '';
    String summary = '';

    // Skip scraping for faster loading - use available content
    fullContent = article['content'] ?? article['description'] ?? '';

    // Generate summary quickly
    if (_ollamaAvailable) {
      try {
        summary = await _generateSummaryWithOllama(
          fullContent,
          widget.childAge,
        ).timeout(Duration(seconds: 10));
      } catch (e) {
        summary = _createSimpleSummary(fullContent, widget.childAge);
      }
    } else {
      summary = _createSimpleSummary(fullContent, widget.childAge);
    }

    return ArticleSummary(
      title: article['title'] ?? 'News Story ${index + 1}',
      summary: summary,
      url: article['url'] ?? '',
      fullContent: fullContent,
      wasScraped: false,
    );
  }

  String _createSimpleSummary(String content, String age) {
    if (content.isEmpty) return 'No summary available for this story.';

    String truncated = content.length > 300
        ? content.substring(0, 300)
        : content;

    truncated = truncated.replaceAll(RegExp(r'[^\w\s.,!?]'), '');

    return 'Here\'s what happened: $truncated... This is an interesting story that helps us learn about the world!';
  }

  Future<List<Map<String, dynamic>>> _fetchNewsArticles(int count) async {
    try {
      String query = '';

      // Use custom prompt if available
      if (widget.customPrompt.isNotEmpty) {
        // Format the custom prompt to be more search-friendly
        String formattedPrompt = widget.customPrompt
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        // Add some context to make it more relevant for kids
        String kidFriendlyPrompt = '$formattedPrompt';

        query = kidFriendlyPrompt;
      } else if (widget.selectedCategories.isNotEmpty &&
          !widget.selectedCategories.contains('Custom')) {
        // Build query from selected categories - enhanced with more specific terms
        List<String> searchTerms = [];
        for (String category in widget.selectedCategories) {
          switch (category) {
            case 'Animals & Nature':
              searchTerms.addAll([
                'animals',
                'wildlife',
                'nature',
                'pets',
                'zoo',
                'conservation',
              ]);
              break;
            case 'Science & Space':
              searchTerms.addAll([
                'science',
                'space',
                'NASA',
                'discovery',
                'research',
                'astronomy',
              ]);
              break;
            case 'Sports':
              searchTerms.addAll([
                'sports',
                'football',
                'basketball',
                'soccer',
                'baseball',
                'olympics',
              ]);
              break;
            case 'Technology & Gaming':
              searchTerms.addAll([
                'technology',
                'gaming',
                'robots',
                'computers',
                'AI',
                'tech',
              ]);
              break;
            case 'Arts & Music & Movies':
              searchTerms.addAll([
                'music',
                'art',
                'movies',
                'entertainment',
                'concert',
                'artist',
              ]);
              break;
            case 'Environment':
              searchTerms.addAll([
                'environment',
                'climate',
                'recycling',
                'green',
                'renewable',
                'sustainability',
              ]);
              break;
            case 'Adventure & Travel':
              searchTerms.addAll([
                'travel',
                'adventure',
                'exploration',
                'tourism',
                'vacation',
              ]);
              break;
            case 'Food & Cooking':
              searchTerms.addAll([
                'food',
                'cooking',
                'recipe',
                'restaurant',
                'chef',
                'nutrition',
              ]);
              break;
          }
        }

        // Join terms with OR for better coverage
        query = searchTerms.take(8).join(' OR ');
      }

      final String endpoint = query.isNotEmpty
          ? 'https://newsapi.org/v2/everything?q=($query)&language=en&sortBy=relevancy&pageSize=$count&apiKey=${widget.newsApiKey}&from=${DateTime.now().subtract(Duration(days: 7)).toIso8601String().split('T')[0]}'
          : 'https://newsapi.org/v2/top-headlines?country=us&apiKey=${widget.newsApiKey}&pageSize=$count';

      final response = await http
          .get(Uri.parse(endpoint))
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = data['articles'] as List<dynamic>;

        List<Map<String, dynamic>> validArticles = [];
        for (var article in articles) {
          if (article['title'] != null &&
              article['title'].toString().isNotEmpty &&
              article['title'] != '[Removed]') {
            validArticles.add(article);
          }
        }

        if (validArticles.isEmpty && widget.customPrompt.isNotEmpty) {
          // If no results for custom prompt, try a fallback with just the main keywords
          String simpleQuery = widget.customPrompt
              .split(' ')
              .where((word) => word.length > 3)
              .take(3)
              .join(' ');

          if (simpleQuery.isNotEmpty) {
            final fallbackResponse = await http
                .get(
                  Uri.parse(
                    'https://newsapi.org/v2/everything?q=$simpleQuery&language=en&pageSize=$count&apiKey=${widget.newsApiKey}',
                  ),
                )
                .timeout(Duration(seconds: 10));

            if (fallbackResponse.statusCode == 200) {
              final fallbackData = json.decode(fallbackResponse.body);
              final fallbackArticles =
                  fallbackData['articles'] as List<dynamic>;

              for (var article in fallbackArticles) {
                if (article['title'] != null &&
                    article['title'].toString().isNotEmpty &&
                    article['title'] != '[Removed]') {
                  validArticles.add(article);
                }
              }
            }
          }
        }

        if (validArticles.isEmpty) {
          return _getFallbackArticles();
        }

        return validArticles.take(count).toList().cast<Map<String, dynamic>>();
      } else {
        return _getFallbackArticles();
      }
    } catch (e) {
      return _getFallbackArticles();
    }
  }

  List<Map<String, dynamic>> _getFallbackArticles() {
    return [
      {
        'title': 'Scientists Discover New Dinosaur Species',
        'description':
            'Paleontologists have discovered fossils of a new dinosaur species in Argentina.',
        'content':
            'A team of scientists working in Argentina have made an exciting discovery...',
        'url': '',
      },
      {
        'title': 'Space Station Gets New Solar Panels',
        'description':
            'The International Space Station received new solar panels to help power experiments.',
        'content':
            'Astronauts completed a spacewalk to install new solar panels...',
        'url': '',
      },
      {
        'title': 'Young Inventor Creates Recycling Robot',
        'description':
            'A 12-year-old student invented a robot that can sort recycling materials.',
        'content':
            'An innovative young inventor has created a solution to help with recycling...',
        'url': '',
      },
    ];
  }

  Future<String> _generateSummaryWithOllama(String content, String age) async {
    if (content.isEmpty || !_ollamaAvailable) {
      return _createSimpleSummary(content, age);
    }

    try {
      String truncatedContent = content.length > 1000
          ? content.substring(0, 1000)
          : content;

      final response = await http
          .post(
            Uri.parse('${widget.ollamaBaseUrl}/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'model': 'llama3.2',
              'prompt':
                  'Summarize for a $age year old in 2-3 simple sentences: $truncatedContent',
              'stream': false,
              'options': {'temperature': 0.5, 'max_tokens': 150},
            }),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String summary = data['response'] ?? '';

        if (summary.isEmpty) {
          return _createSimpleSummary(content, age);
        }

        return summary.replaceAll(RegExp(r'\n+'), ' ').trim();
      } else {
        return _createSimpleSummary(content, age);
      }
    } catch (e) {
      return _createSimpleSummary(content, age);
    }
  }
}

class CategoriesSelectionScreen extends StatefulWidget {
  final String childAge;
  final Function(List<String>) onCategoriesSelected;
  final Function(String) onCustomPromptSelected; // ADDED: Custom prompt handler

  CategoriesSelectionScreen({
    required this.childAge,
    required this.onCategoriesSelected,
    required this.onCustomPromptSelected, // ADDED: Required custom prompt handler
  });

  @override
  _CategoriesSelectionScreenState createState() =>
      _CategoriesSelectionScreenState();
}

class _CategoriesSelectionScreenState extends State<CategoriesSelectionScreen> {
  List<String> selectedCategories = [];
  final List<Map<String, dynamic>> categories = [
    {'name': 'Animals & Nature', 'icon': Icons.pets, 'color': Colors.green},
    {'name': 'Science & Space', 'icon': Icons.science, 'color': Colors.blue},
    {'name': 'Sports', 'icon': Icons.sports_soccer, 'color': Colors.orange},
    {
      'name': 'Technology & Gaming',
      'icon': Icons.videogame_asset,
      'color': Colors.purple,
    },
    {
      'name': 'Arts & Music & Movies',
      'icon': Icons.palette,
      'color': Colors.pink,
    },
    {'name': 'Environment', 'icon': Icons.eco, 'color': Colors.teal},
    {
      'name': 'Adventure & Travel',
      'icon': Icons.explore,
      'color': Colors.indigo,
    },
    {'name': 'Food & Cooking', 'icon': Icons.restaurant, 'color': Colors.amber},
  ];

  final TextEditingController _customPromptController = TextEditingController();
  bool _showCustomPromptInput = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _showCustomPromptInput
                  ? _buildCustomPromptInput()
                  : _buildCategoriesGrid(),
            ),
            if (!_showCustomPromptInput) _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.interests, size: 48, color: Color(0xFF2E7D96)),
          SizedBox(height: 16),
          Text(
            'What interests you?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Pick topics you want to read about!',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF2E7D96).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Age: ${widget.childAge} years old',
              style: TextStyle(
                color: Color(0xFF2E7D96),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        itemCount: categories.length + 1, // +1 for the custom option
        itemBuilder: (context, index) {
          // Add custom prompt option at the end
          if (index == categories.length) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _showCustomPromptInput = true;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit, size: 48, color: Colors.grey[600]),
                    SizedBox(height: 12),
                    Text(
                      'Custom Topic',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final category = categories[index];
          final isSelected = selectedCategories.contains(category['name']);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  selectedCategories.remove(category['name']);
                } else {
                  selectedCategories.add(category['name']);
                }
              });
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected
                    ? category['color'].withOpacity(0.2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? category['color'] : Colors.grey[300]!,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? category['color'].withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    category['icon'],
                    size: 48,
                    color: isSelected ? category['color'] : Colors.grey[600],
                  ),
                  SizedBox(height: 12),
                  Text(
                    category['name'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? category['color'] : Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isSelected) ...[
                    SizedBox(height: 8),
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: category['color'],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomPromptInput() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Enter Your Custom Topic',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D96),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _customPromptController,
            decoration: InputDecoration(
              hintText:
                  'e.g., "dinosaurs", "space exploration", or "how do volcanoes work?"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF2E7D96)),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_customPromptController.text.trim().isNotEmpty) {
                      widget.onCustomPromptSelected(
                        _customPromptController.text.trim(),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D96),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Search This Topic',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showCustomPromptInput = false;
                    _customPromptController.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (selectedCategories.isEmpty)
            Text(
              'Select at least one topic to continue',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          if (selectedCategories.isNotEmpty)
            Text(
              '${selectedCategories.length} topic${selectedCategories.length > 1 ? 's' : ''} selected',
              style: TextStyle(
                color: Color(0xFF2E7D96),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selectedCategories.isEmpty
                  ? null
                  : () {
                      widget.onCategoriesSelected(selectedCategories);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D96),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Start Reading!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ArticleDetailScreen extends StatefulWidget {
  final ArticleSummary article;
  final String ollamaBaseUrl;
  final VoidCallback onLike;
  ArticleDetailScreen({
    required this.article,
    required this.ollamaBaseUrl,
    required this.onLike,
  });
  @override
  _ArticleDetailScreenState createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLiked = false;
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<QAMessage> _qaMessages = [];
  bool _isAsking = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2E7D96)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Story Details',
          style: TextStyle(
            color: Color(0xFF2E7D96),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.article.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D96),
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.article.summary,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                        height: 1.6,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!_isLiked) {
                              widget.onLike();
                              setState(() {
                                _isLiked = true;
                              });
                            }
                          },
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.red : Colors.white,
                          ),
                          label: Text(
                            _isLiked ? 'Liked!' : 'Like This Story',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLiked
                                ? Colors.grey
                                : Color(0xFF2E7D96),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.article.url.isNotEmpty) ...[
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: () =>
                          _showUrlDialog(context, widget.article.url),
                      child: Text(
                        'View Original Article',
                        style: TextStyle(
                          color: Color(0xFF2E7D96),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 32),
                  _buildQASection(),
                ],
              ),
            ),
          ),
          _buildQuestionInput(),
        ],
      ),
    );
  }

  Widget _buildQASection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ask Questions About This Story',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D96),
          ),
        ),
        SizedBox(height: 16),
        if (_qaMessages.isEmpty)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.question_answer, size: 48, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No questions yet!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ask me anything about this story and I\'ll help explain it!',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._qaMessages.map((message) => _buildQAMessage(message)).toList(),
      ],
    );
  }

  Widget _buildQAMessage(QAMessage message) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Container(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF2E7D96),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.question,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          SizedBox(height: 8),
          // Answer
          Container(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.answer,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  hintText: 'Ask a question about this story...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Color(0xFF2E7D96)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF2E7D96),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                onPressed: _isAsking ? null : _askQuestion,
                icon: _isAsking
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUrlDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Original Article'),
          content: Text(
            'This will open the original news article in your browser: $url',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // In a real app, you would use url_launcher package
                // launch(url);
              },
              child: Text('Open'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _askQuestion() async {
    if (_questionController.text.trim().isEmpty) return;
    final question = _questionController.text.trim();
    _questionController.clear();
    setState(() {
      _isAsking = true;
    });
    try {
      final response = await http
          .post(
            Uri.parse('${widget.ollamaBaseUrl}/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'model': 'llama3.2',
              'prompt':
                  'Answer this question about the news article in a way a child can understand, keep it at 3 sentences max, using bullet points formatted well. Article: "${widget.article.summary}" Question: "$question"',
              'stream': false,
            }),
          )
          .timeout(Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final answer =
            data['response'] ?? 'Sorry, I couldn\'t answer that question.';
        setState(() {
          _qaMessages.add(QAMessage(question: question, answer: answer));
        });
        // Scroll to bottom after adding new message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      setState(() {
        _qaMessages.add(
          QAMessage(
            question: question,
            answer:
                'Sorry, I had trouble answering your question. Please try again!',
          ),
        );
      });
    } finally {
      setState(() {
        _isAsking = false;
      });
    }
  }
}

class ParentLoginScreen extends StatefulWidget {
  final List<ReadingActivity> activities;
  final List<ArticleSummary> articles;
  final String ollamaBaseUrl;
  ParentLoginScreen({
    required this.activities,
    required this.articles,
    required this.ollamaBaseUrl,
    Key? key,
  }) : super(key: key);
  @override
  _ParentLoginScreenState createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoggedIn = false;
  String _errorMessage = '';
  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return _buildLoginScreen();
    }
    return _buildDashboard();
  }

  Widget _buildLoginScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E7D96), Color(0xFF4A90A4)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings, size: 80, color: Colors.white),
              SizedBox(height: 24),
              Text(
                'Parent Zone',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Monitor Your Child\'s Reading',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 48),
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Enter Parent Password',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D96),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF2E7D96)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D96),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Access Dashboard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Parent Dashboard',
          style: TextStyle(
            color: Color(0xFF2E7D96),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isLoggedIn = false;
                _passwordController.clear();
                _errorMessage = '';
              });
            },
            icon: Icon(Icons.logout, color: Color(0xFF2E7D96)),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(),
            SizedBox(height: 24),
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D96),
              ),
            ),
            SizedBox(height: 16),
            Expanded(child: _buildActivityList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final totalArticles = widget.articles.length;
    final likedArticles = widget.activities
        .where((a) => a.action == 'liked')
        .length;
    final openedArticles = widget.activities
        .where((a) => a.action == 'opened')
        .toSet()
        .length;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Stories Read',
            openedArticles.toString(),
            Icons.article,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Stories Liked',
            likedArticles.toString(),
            Icons.favorite,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Stories',
            totalArticles.toString(),
            Icons.library_books,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Color(0xFF2E7D96), size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D96),
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    if (widget.activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: widget.activities.length,
      itemBuilder: (context, index) {
        final activity =
            widget.activities[widget.activities.length - 1 - index];
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: activity.action == 'liked'
                  ? Colors.red[100]
                  : Colors.blue[100],
              child: Icon(
                activity.action == 'liked' ? Icons.favorite : Icons.visibility,
                color: activity.action == 'liked' ? Colors.red : Colors.blue,
                size: 20,
              ),
            ),
            title: Text(
              activity.articleTitle,
              style: TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${activity.action.capitalize()} • ${_formatTimestamp(activity.timestamp)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _login() {
    if (_passwordController.text == 'parent123') {
      setState(() {
        _isLoggedIn = true;
        _errorMessage = '';
      });
    } else {
      setState(() {
        _errorMessage = 'Invalid password. Try "parent123"';
      });
    }
  }
}

// Data Models
class ArticleSummary {
  final String title;
  final String summary;
  final String url;
  final String fullContent;
  final bool wasScraped;
  ArticleSummary({
    required this.title,
    required this.summary,
    required this.url,
    required this.fullContent,
    this.wasScraped = false,
  });
}

class ReadingActivity {
  final String articleTitle;
  final String action;
  final DateTime timestamp;
  ReadingActivity({
    required this.articleTitle,
    required this.action,
    required this.timestamp,
  });
}

class QAMessage {
  final String question;
  final String answer;
  QAMessage({required this.question, required this.answer});
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
