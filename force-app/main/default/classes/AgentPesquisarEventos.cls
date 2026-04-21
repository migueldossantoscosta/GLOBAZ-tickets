public with sharing class AgentPesquisarEventos {

    public class Input {
        @InvocableVariable(label='Nome do Evento (ou parte dele)' required=false)
        public String nomeEvento;

        @InvocableVariable(label='Cidade' required=false)
        public String cidade;

        @InvocableVariable(label='Categoria' required=false)
        public String categoria;

        @InvocableVariable(label='Data início (YYYY-MM-DD)' required=false)
        public String dataInicio;

        @InvocableVariable(label='Data fim (YYYY-MM-DD)' required=false)
        public String dataFim;

        @InvocableVariable(label='Preço máximo' required=false)
        public Decimal precoMax;

        @InvocableVariable(label='Só destaques?' required=false)
        public Boolean apenasDestaques;
    }

    public class Output {
        @InvocableVariable(label='Eventos encontrados (JSON)')
        public String eventosJson;

        @InvocableVariable(label='Número de eventos')
        public Decimal totalEventos; // Alterado para Decimal para evitar erro de validação no Agentforce

        @InvocableVariable(label='Mensagem formatada para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Pesquisar Eventos'
        description = 'Pesquisa eventos ativos pelo nome do evento, cidade, categoria ou data. Retorna lista formatada.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> pesquisarEventos(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];

            // 1. Base da Query
            String soql =
                'SELECT Id, Name, DataEvento__c, LocalizacaoEvento__c, ' +
                '       CategoriaPrincipal__c, URLImagem__c, Destaque__c, ' +
                '       PrecoBilhete__c, Recinto__r.Cidade__c, Recinto__r.Name, ' +
                '       CapacidadeMaxima__c ' +
                'FROM   Evento__c ' +
                'WHERE  EstadoEvento__c = \'Ativo\' ' +
                'AND    DataEvento__c  >= TODAY ';

            String nomeBusca = '';
            String cidadeBusca = '';
            String catBusca = '';

            // 2. Filtros Dinâmicos
            if (String.isNotBlank(inp.nomeEvento)) {
                nomeBusca = '%' + String.escapeSingleQuotes(inp.nomeEvento) + '%';
                soql += 'AND Name LIKE :nomeBusca ';
            }
            if (String.isNotBlank(inp.cidade)) {
                cidadeBusca = '%' + String.escapeSingleQuotes(inp.cidade) + '%';
                soql += 'AND Recinto__r.Cidade__c LIKE :cidadeBusca ';
            }
            if (String.isNotBlank(inp.categoria)) {
                catBusca = '%' + String.escapeSingleQuotes(inp.categoria) + '%';
                soql += 'AND CategoriaPrincipal__c LIKE :catBusca ';
            }
            if (String.isNotBlank(inp.dataInicio)) {
                soql += 'AND DataEvento__c >= ' + inp.dataInicio + ' ';
            }
            if (String.isNotBlank(inp.dataFim)) {
                soql += 'AND DataEvento__c <= ' + inp.dataFim + ' ';
            }
            if (inp.precoMax != null && inp.precoMax > 0) {
                soql += 'AND PrecoBilhete__c <= ' + inp.precoMax + ' ';
            }


            soql += 'ORDER BY Destaque__c DESC, DataEvento__c ASC LIMIT 50';

            // 3. Execução
            // Nota: Se usares variáveis com ":" dentro de Database.query, elas têm de estar no scope.
            // Para simplificar a query dinâmica com o LIKE, as variáveis nomeBusca e cidadeBusca funcionam aqui.
            List<Evento__c> eventos = Database.query(soql);
            out.totalEventos = (Decimal) eventos.size();

            if (eventos.isEmpty()) {
                out.mensagemChat = 'Infelizmente não encontrei nenhum evento com o nome "' + (inp.nomeEvento ?? '') + '". Queres tentar outro nome ou cidade?';
                out.eventosJson  = '[]';
                return new List<Output>{ out };
            }

            // 4. Construção da Resposta Visual para o Bot
            List<Map<String, Object>> listaJson = new List<Map<String, Object>>();
            String msg = 'Encontrei estas opções para ti:\n\n';

            String[] emojis = new String[]{ '🎵', '🎭', '🎸', '🎪', '✨' };
            Integer idx = 0;

            for (Evento__c ev : eventos) {
                String emoji     = emojis[Math.mod(idx, emojis.size())];
                String dataStr   = ev.DataEvento__c != null ? ev.DataEvento__c.format() : 'Data a confirmar';
                
                // Cálculo de preço com IVA (exemplo 23%)
                Decimal precoComIva = ev.PrecoBilhete__c != null ? (ev.PrecoBilhete__c * 1.23).setScale(2) : null;
                String precoStr = precoComIva != null ? String.valueOf(precoComIva) + '€' : 'Preço sob consulta';
                
                String cidade  = ev.Recinto__r != null ? ev.Recinto__r.Cidade__c : '';
                String recinto = ev.Recinto__r != null ? ev.Recinto__r.Name : '';

                msg += emoji + ' *' + ev.Name + '*\n';
                msg += '   📅 ' + dataStr + '\n';
                msg += '   📍 ' + recinto + (String.isNotBlank(cidade) ? ', ' + cidade : '') + '\n';
                msg += '   💶 A partir de ' + precoStr + '\n\n';

                listaJson.add(new Map<String, Object>{
                    'id'        => ev.Id,
                    'nome'      => ev.Name,
                    'data'      => dataStr,
                    'recinto'   => recinto,
                    'cidade'    => cidade,
                    'precoIva'  => precoComIva
                });
                idx++;
            }

            msg += 'Diz-me o nome de um deles para avançarmos com a reserva! 😊';
            out.mensagemChat = msg;
            out.eventosJson  = JSON.serialize(listaJson);

        } catch (Exception e) {
            out.erroMsg      = 'Erro: ' + e.getMessage();
            out.mensagemChat = 'Ocorreu um problema técnico ao pesquisar. Tenta escrever o nome do evento de outra forma.';
            out.totalEventos = 0;
            out.eventosJson  = '[]';
        }

        return new List<Output>{ out };
    }
}