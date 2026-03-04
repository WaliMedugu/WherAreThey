import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ModeratorHistoryScreen extends StatelessWidget {
  final Map<String, dynamic> moderator;

  const ModeratorHistoryScreen({super.key, required this.moderator});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final moderatorId = moderator['id'];
    final moderatorName = moderator['full_name'] ?? 'Moderator';

    return Scaffold(
      appBar: AppBar(
        title: Text("$moderatorName's History", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF8A7650),
        elevation: 0,
      ),
      body: FutureBuilder(
        future: supabase
            .from('moderation_history')
            .select('*, cases(*)')
            .eq('moderator_id', moderatorId)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading history: ${snapshot.error}"));
          }
          final history = snapshot.data as List<dynamic>? ?? [];
          if (history.isEmpty) {
            return const Center(child: Text("No history found for this moderator."));
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final caseData = item['cases'];
              final action = item['action'];
              IconData actionIcon;
              Color color;
              
              if (action == 'approved') {
                actionIcon = Icons.check_circle;
                color = Colors.green;
              } else if (action == 'denied') {
                actionIcon = Icons.cancel;
                color = Colors.red;
              } else {
                actionIcon = Icons.visibility_off;
                color = Colors.orange;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(
                      actionIcon,
                      color: color,
                    ),
                  ),
                  title: Text(caseData?['name'] ?? "Unknown Case", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Action: ${action.toString().toUpperCase()}"),
                      if (item['reason'] != null)
                        Text("Reason: ${item['reason']}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      Text(
                        "Date: ${DateTime.parse(item['created_at']).toLocal().toString().split('.')[0]}",
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
