public with sharing class AgentPesquisarEventos {

    public class Input {
        @InvocableVariable(label='Cidade' required=false)
        public String cidade;

        @InvocableVariable(label='Categoria' required=false)
        public String categoria;

        @InvocableVariable(label='Artista / nome a pesquisar' required=false)
        public String nomeArtista;

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
        public Integer totalEventos;

        @InvocableVariable(label='Mensagem formatada para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Pesquisar Eventos'
        description = 'Pesquisa eventos ativos por cidade, categoria, artista, data e preço. Retorna lista formatada para o chat.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> pesquisarEventos(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];

            // Construir query dinâmica
            String soql =
                'SELECT Id, Name, DataEvento__c, LocalizacaoEvento__c, ' +
                '       CategoriaPrincipal__c, URLImagem__c, Destaque__c, ' +
                '       PrecoBilhete__c, Recinto__r.Cidade__c, Recinto__r.Name, ' +
                '       CapacidadeMaxima__c ' +
                'FROM   Evento__c ' +
                'WHERE  EstadoEvento__c = \'Ativo\' ' +
                'AND    DataEvento__c  >= TODAY ';

            if (String.isNotBlank(inp.cidade)) {
                soql += 'AND Recinto__r.Cidade__c LIKE \'%' + String.escapeSingleQuotes(inp.cidade) + '%\' ';
            }
            if (String.isNotBlank(inp.categoria)) {
                soql += 'AND CategoriaPrincipal__c LIKE \'%' + String.escapeSingleQuotes(inp.categoria) + '%\' ';
            }
            if (String.isNotBlank(inp.nomeArtista)) {
                soql += 'AND Name LIKE \'%' + String.escapeSingleQuotes(inp.nomeArtista) + '%\' ';
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
            if (inp.apenasDestaques == true) {
                soql += 'AND Destaque__c = true ';
            }

            soql += 'ORDER BY DataEvento__c ASC LIMIT 5';

            List<Evento__c> eventos = Database.query(soql);
            out.totalEventos = eventos.size();

            if (eventos.isEmpty()) {
                out.mensagemChat = 'Não encontrei eventos disponíveis com esses critérios. Queres que alargue a pesquisa?';
                out.eventosJson  = '[]';
                return new List<Output>{ out };
            }

            // Construir JSON e mensagem
            List<Map<String, Object>> listaJson = new List<Map<String, Object>>();
            String msg = 'Encontrei ' + eventos.size() + ' evento(s) para ti:\n\n';

            String[] emojis = new String[]{ '🎵', '🎭', '⚽', '🎪', '🎸' };
            Integer idx = 0;

            for (Evento__c ev : eventos) {
                String emoji     = emojis[Math.mod(idx, emojis.size())];
                String dataStr   = ev.DataEvento__c != null
                    ? ev.DataEvento__c.format() : 'Data a confirmar';
                String precoStr  = ev.PrecoBilhete__c != null
                    ? String.valueOf((ev.PrecoBilhete__c * 1.23).setScale(2)) + '€'
                    : 'Preço a anunciar';
                String cidade    = ev.Recinto__r != null ? ev.Recinto__r.Cidade__c : '';
                String recinto   = ev.Recinto__r != null ? ev.Recinto__r.Name : '';

                msg += emoji + ' *' + ev.Name + '*\n';
                msg += '   📅 ' + dataStr + '\n';
                msg += '   📍 ' + recinto + (String.isNotBlank(cidade) ? ', ' + cidade : '') + '\n';
                msg += '   💶 A partir de ' + precoStr + '\n\n';

                Map<String, Object> m = new Map<String, Object>{
                    'id'        => ev.Id,
                    'nome'      => ev.Name,
                    'data'      => dataStr,
                    'recinto'   => recinto,
                    'cidade'    => cidade,
                    'preco'     => ev.PrecoBilhete__c,
                    'precoIva'  => ev.PrecoBilhete__c != null ? (ev.PrecoBilhete__c * 1.23).setScale(2) : null,
                    'categoria' => ev.CategoriaPrincipal__c,
                    'destaque'  => ev.Destaque__c
                };
                listaJson.add(m);
                idx++;
            }

            msg += 'Queres saber mais sobre algum destes eventos? 😊';
            out.mensagemChat = msg;
            out.eventosJson  = JSON.serialize(listaJson);

        } catch (Exception e) {
            out.erroMsg      = 'Erro ao pesquisar eventos: ' + e.getMessage();
            out.mensagemChat = 'Ocorreu um erro na pesquisa. Tenta novamente.';
            out.eventosJson  = '[]';
            out.totalEventos = 0;
        }

        return new List<Output>{ out };
    }
}