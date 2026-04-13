public with sharing class AgentDetalheEvento {

    public class Input {
        @InvocableVariable(label='ID do Evento' required=true)
        public String eventoId;
    }

    public class Output {
        @InvocableVariable(label='Nome do evento')
        public String nomeEvento;

        @InvocableVariable(label='ID do Evento' description='ID persistente para o checkout')
        public String eventoIdOut;

        @InvocableVariable(label='Data formatada')
        public String dataEvento;

        @InvocableVariable(label='Recinto e cidade')
        public String recinto;

        @InvocableVariable(label='Categoria')
        public String categoria;

        @InvocableVariable(label='Classificação etária')
        public String classificacaoEtaria;

        @InvocableVariable(label='Preço Geral com IVA')
        public Decimal precoGeral;

        @InvocableVariable(label='Preço VIP com IVA')
        public Decimal precoVIP;

        @InvocableVariable(label='Preço Camarote com IVA')
        public Decimal precoCamarote;

        @InvocableVariable(label='Extras disponíveis (JSON)')
        public String extrasJson;

        @InvocableVariable(label='Lugares vendidos')
        public Decimal lugaresVendidos;

        @InvocableVariable(label='Capacidade máxima')
        public Decimal capacidadeMaxima;

        @InvocableVariable(label='Lugares disponíveis')
        public Decimal lugaresDisponiveis;

        @InvocableVariable(label='Mensagem formatada para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(label='Agente — Detalhe de Evento' description='Retorna informação completa de um evento consultando o Pricebook.' category='GLOBAZ Tickets')
    public static List<Output> obterDetalhe(List<Input> inputs) {
        Output out = new Output();
        try {
            Id evId = (Id) inputs[0].eventoId;

            List<Evento__c> evs = [
                SELECT Id, Name, DataEvento__c, LocalizacaoEvento__c, CategoriaPrincipal__c, 
                       ClassificacaoEtaria__c, CapacidadeMaxima__c, Pricebook__c, PrecoBilhete__c,
                       Recinto__r.Name, Recinto__r.Cidade__c
                FROM   Evento__c
                WHERE  Id = :evId LIMIT 1
            ];
            if (evs.isEmpty()) {
                out.erroMsg = 'Evento não encontrado.';
                return new List<Output>{ out };
            }
            Evento__c ev = evs[0];

            out.nomeEvento       = ev.Name;
            out.eventoIdOut      = ev.Id;
            out.dataEvento       = ev.DataEvento__c != null ? ev.DataEvento__c.format() : '';
            out.recinto          = (ev.Recinto__r != null ? ev.Recinto__r.Name + ', ' + ev.Recinto__r.Cidade__c : ev.LocalizacaoEvento__c);
            out.categoria        = ev.CategoriaPrincipal__c;
            out.classificacaoEtaria = ev.ClassificacaoEtaria__c;
            out.capacidadeMaxima = ev.CapacidadeMaxima__c != null ? ev.CapacidadeMaxima__c.intValue() : 0;

            // --- LÓGICA DE PREÇOS PELO PRICEBOOK DO EVENTO ---
            if (ev.Pricebook__c != null) {
                List<Map<String, Object>> extras = new List<Map<String, Object>>();
                
                // Vamos buscar TODOS os produtos do Pricebook e filtrar em memória (mais robusto que SOQL complexes)
                for (PricebookEntry pbe : [
                    SELECT UnitPrice, Product2.Name, Product2.ProductCode
                    FROM   PricebookEntry
                    WHERE  Pricebook2Id = :ev.Pricebook__c AND IsActive = true
                ]) {
                    Decimal comIva = (pbe.UnitPrice * 1.23).setScale(2);
                    String nome = pbe.Product2.Name.toLowerCase();
                    String code = (pbe.Product2.ProductCode != null ? pbe.Product2.ProductCode.toLowerCase() : '');

                    // Verificar se é um bilhete base
                    Boolean isTicket = false;
                    if (code.contains('geral') || nome.contains('geral')) {
                        out.precoGeral = comIva;
                        isTicket = true;
                    } else if (code.contains('vip') || nome.contains('vip')) {
                        out.precoVIP = comIva;
                        isTicket = true;
                    } else if (code.contains('camarote') || nome.contains('camarote')) {
                        out.precoCamarote = comIva;
                        isTicket = true;
                    }

                    // Se não for um dos 3 bilhetes principais, é um extra
                    if (!isTicket && !code.startsWith('blt-')) {
                        extras.add(new Map<String, Object>{
                            'pbeId' => pbe.Id,
                            'nome'  => pbe.Product2.Name,
                            'code'  => pbe.Product2.ProductCode,
                            'preco' => comIva
                        });
                    }
                }
                out.extrasJson = JSON.serialize(extras);
            }

            if (out.precoGeral == null && ev.PrecoBilhete__c != null) {
                out.precoGeral = (ev.PrecoBilhete__c * 1.23).setScale(2);
            }

            AggregateResult[] ar = [SELECT COUNT(Id) qtd FROM Bilhete__c WHERE Evento__c = :evId AND EstadoBilhete__c = 'Vendido'];
            out.lugaresVendidos   = ar.isEmpty() ? 0 : (Integer) ar[0].get('qtd');
            out.lugaresDisponiveis = out.capacidadeMaxima - out.lugaresVendidos;

            String msg = '🎟️ *' + out.nomeEvento + '*\n\n' +
                         '📅 ' + out.dataEvento + '\n' +
                         '📍 ' + out.recinto    + '\n' +
                         '🔞 Idade: ' + (out.classificacaoEtaria ?? 'Livre') + '\n\n' +
                         '💶 *Preços (c/ IVA):*\n';
            if (out.precoGeral != null) msg += '   🎫 Geral: ' + out.precoGeral + '€\n';
            if (out.precoVIP != null)   msg += '   ⭐ VIP: ' + out.precoVIP + '€\n';
            if (out.precoCamarote != null) msg += '   🏆 Camarote: ' + out.precoCamarote + '€\n';
            
            // Adicionar serviços associados (extras)
            if (String.isNotBlank(out.extrasJson) && out.extrasJson != '[]') {
                msg += '\n✨ *Serviços Associados:*\n';
                List<Object> extrasList = (List<Object>) JSON.deserializeUntyped(out.extrasJson);
                for (Object obj : extrasList) {
                    Map<String, Object> extra = (Map<String, Object>) obj;
                    msg += '   ➕ ' + (String)extra.get('nome') + ': ' + extra.get('preco') + '€\n';
                }
            }

            out.mensagemChat = msg + '\n🪑 Lugares: ' + out.lugaresDisponiveis + ' / ' + out.capacidadeMaxima +
                               '\n📍 [🗺️ Ver Mapa de Lugares e Escolher Assento](https://orgfarm-64aee8f1dd-dev-ed.develop.my.site.com/globaztickets/EscolherLugar?idEvento=' + out.eventoIdOut + ')';

        } catch (Exception e) {
            out.erroMsg = 'Erro: ' + e.getMessage();
            out.mensagemChat = 'Não consegui obter os detalhes do evento agora.';
        }
        return new List<Output>{ out };
    }
}