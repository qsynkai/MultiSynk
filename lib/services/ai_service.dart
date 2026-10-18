import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/shopping_item.dart';

class AiService {
  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4.1';

  static Future<List<Task>> analyzePriorities(List<Task> tasks) async {
    if (tasks.isEmpty) return tasks;
    if (_apiKey.isEmpty) return tasks;

    final taskList = tasks
        .map((t) => '- ID:${t.id} | ${t.title}'
            '${t.description != null ? " (${t.description})" : ""}'
            '${t.dueDate != null ? " | prazo: ${t.dueDate!.day}/${t.dueDate!.month}" : ""}')
        .join('\n');

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'temperature': 0.3,
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'system',
              'content': 'Você é um assistente de produtividade para pessoas com TDAH. '
                  'Analise tarefas e defina prioridades com base em urgência real, '
                  'impacto financeiro, prazo e consequências de atraso. '
                  'Responda SEMPRE em JSON válido, sem texto extra.',
            },
            {
              'role': 'user',
              'content': '''Analise estas tarefas e defina a prioridade de cada uma.

Tarefas:
$taskList

Responda neste formato JSON:
{
  "tasks": [
    {"id": "ID_DA_TAREFA", "priority": "urgent|high|medium|low", "reason": "motivo em 1 frase curta em português"}
  ]
}

Foque no que a pessoa NÃO pode esquecer. Seja direto e objetivo.''',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;

        final cleanContent = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final jsonData = jsonDecode(cleanContent);
        final aiTasks = jsonData['tasks'] as List;

        return tasks.map((task) {
          final aiTask = aiTasks.firstWhere(
            (at) => at['id'] == task.id,
            orElse: () => null,
          );
          if (aiTask == null) return task;
          return task.copyWith(
            aiPriority: TaskPriority.values.byName(aiTask['priority']),
            aiReason: aiTask['reason'],
          );
        }).toList();
      }
    } catch (_) {}

    return tasks;
  }

  static Future<String> analyzeFinancialContext({
    required double monthIncome,
    required double fiorinoMonthAvailable,
    required double studioMonthProlabore,
    required double monthExpenses,
    required double weekExpenses,
    required double pendingReceivables,
    required double pendingFixed,
    required double weeklyBudget,
    required int weeksUntilMonthEnd,
    required List<Map<String, dynamic>> activeFixed,
    required double cardTotal,
  }) async {
    if (_apiKey.isEmpty) return 'Chave de API não configurada.';

    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final now = DateTime.now();
    final monthName = DateFormat('MMMM', 'pt_BR').format(now);
    final daysLeft = DateTime(now.year, now.month + 1, 0).difference(now).inDays;

    final fixedLines = activeFixed.isEmpty
        ? '  (nenhuma cadastrada)'
        : activeFixed.map((fe) {
            final daysUntilDue = (fe['due_day'] as int) - now.day;
            final dueSoon = daysUntilDue >= 0 && daysUntilDue <= 5;
            final applied = fe['applied'] as bool;
            return '  • ${fe['name']}: ${fmt.format(fe['amount'])} | vence dia ${fe['due_day']}'
                '${dueSoon ? ' ⚠️ EM ${daysUntilDue} DIAS' : ''}'
                ' | ${applied ? 'já lançada' : 'PENDENTE - não lançada ainda'}';
          }).join('\n');

    final context = '''
Data: ${now.day}/${now.month}/${now.year} — $monthName ($daysLeft dias restantes)

=== RECEITAS DO MÊS ===
• Pessoal (Finance): ${fmt.format(monthIncome - fiorinoMonthAvailable - studioMonthProlabore)}
• Fiorino (disponível após cofrinhos): ${fmt.format(fiorinoMonthAvailable)}
• Studio pró-labore: ${fmt.format(studioMonthProlabore)}
• Total receita mês: ${fmt.format(monthIncome)}
• A receber (pendente): ${fmt.format(pendingReceivables)}

=== DESPESAS DO MÊS ===
• Gastos registrados: ${fmt.format(monthExpenses)}
• Gastos desta semana: ${fmt.format(weekExpenses)}
• Faturas de cartão (ciclo atual): ${fmt.format(cardTotal)}

=== DESPESAS FIXAS ATIVAS ===
$fixedLines
• Total fixas pessoais pendentes: ${fmt.format(pendingFixed)}

=== ORÇAMENTO ===
• Disponível real (após fixas): ${fmt.format(monthIncome + pendingReceivables - monthExpenses - pendingFixed)}
• Semanas até fim do mês: $weeksUntilMonthEnd
• Pode gastar esta semana: ${fmt.format(weeklyBudget)}
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'model': _model,
          'temperature': 0.4,
          'max_tokens': 600,
          'messages': [
            {
              'role': 'system',
              'content': 'Você é um consultor financeiro pessoal para alguém com TDAH. '
                  'Analise o contexto financeiro e dê uma análise objetiva e direta. '
                  'Use linguagem simples, seja específico com valores. '
                  'Destaque riscos reais (fixas não pagas, saldo negativo, cartão vencendo). '
                  'Dê 2-3 ações concretas para os próximos dias. '
                  'Máximo 5 parágrafos curtos. Não use markdown complexo, só texto.',
            },
            {
              'role': 'user',
              'content': 'Analise minha situação financeira atual:\n\n$context',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] as String;
      }
      return 'Não foi possível gerar a análise. Tente novamente.';
    } catch (_) {
      return 'Erro ao conectar com a IA. Verifique sua conexão.';
    }
  }

  static Future<List<ShoppingItem>> analyzeShoppingPriorities(List<ShoppingItem> items) async {
    if (items.isEmpty) return items;
    if (_apiKey.isEmpty) return items;

    final list = items
        .map((i) => '- ID:${i.id} | ${i.description}'
            ' (qtd: ${i.quantity})'
            '${i.estimatedPrice != null ? " | estimado: R\$${i.estimatedPrice!.toStringAsFixed(2)}" : ""}'
            ' | categoria: ${i.category.name}')
        .join('\n');

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'temperature': 0.3,
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'system',
              'content': 'Você é um assistente financeiro para pessoas com TDAH. '
                  'Analise itens de compra e defina prioridade real: '
                  'urgent = precisa urgente/falta em casa, high = importante mas pode esperar alguns dias, '
                  'medium = bom ter, low = desejo/não essencial. '
                  'Responda SEMPRE em JSON válido, sem texto extra.',
            },
            {
              'role': 'user',
              'content': '''Analise estes itens da lista de compras e defina a prioridade de cada um.

Itens:
$list

Responda neste formato JSON:
{
  "items": [
    {"id": "ID_DO_ITEM", "priority": "urgent|high|medium|low", "reason": "motivo em 1 frase curta em português"}
  ]
}''',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        final cleanContent = content.replaceAll('```json', '').replaceAll('```', '').trim();
        final jsonData = jsonDecode(cleanContent);
        final aiItems = jsonData['items'] as List;

        return items.map((item) {
          final ai = aiItems.firstWhere((a) => a['id'] == item.id, orElse: () => null);
          if (ai == null) return item;
          return item.copyWith(
            aiPriority: ShoppingPriority.values.byName(ai['priority']),
            aiReason: ai['reason'],
          );
        }).toList();
      }
    } catch (_) {}

    return items;
  }
}
