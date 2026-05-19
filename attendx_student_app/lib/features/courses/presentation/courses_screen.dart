import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/widgets/main_bottom_nav.dart';

class CourseInfo {
  final String id;
  final String code;
  final String name;
  final int credits;

  const CourseInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
  });

  factory CourseInfo.fromJson(Map<String, dynamic> j) => CourseInfo(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        credits: (j['credits'] as num?)?.toInt() ?? 0,
      );
}

final _coursesProvider = FutureProvider<List<CourseInfo>>((ref) async {
  final dio = ApiClient().dio;
  final res = await dio.get(ApiEndpoints.studentCourses);
  final list = res.data['data'] as List<dynamic>;
  return list
      .map((e) => CourseInfo.fromJson(e as Map<String, dynamic>))
      .toList();
});

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_coursesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Courses')),
      bottomNavigationBar: const MainBottomNav(currentIndex: 0),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                e is DioException
                    ? (e.response?.data?['error'] as String? ?? 'Load failed')
                    : 'Load failed',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(_coursesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (courses) => courses.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No enrolled courses',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(_coursesProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: courses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _CourseCard(course: courses[i]),
                ),
              ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseInfo course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  course.code.substring(0, course.code.length.clamp(0, 2)),
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(course.code,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${course.credits} cr',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
