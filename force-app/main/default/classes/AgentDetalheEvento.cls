public with sharing class AgentDetalheEvento {

    public class Input {
        @InvocableVariable(label='ID do Evento' required=true)
        public String eventoId;
    }

    public class Output {
        @InvocableVariable(label='Nome do evento')
        public String nomeEvento;

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
        public Decimal lugaresVendidos; // De Integer para Decimal

        @InvocableVariable(label='Capacidade máxima')
        public Decimal capacidadeMaxima; // De Integer para Decimal

        @InvocableVariable(label='Lugares disponíveis')
        public Decimal lugaresDisponiveis; // De Integer para Decimal

        @InvocableVariable(label='Mensagem formatada para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Detalhe de Evento'
        description = 'Retorna informação completa de um evento: preços por tipo (Geral/VIP/Camarote), extras e lugares disponíveis.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> obterDetalhe(List<Input> inputs) {
        Output out = new Output();
        try {
            Id evId = (Id) inputs[0].eventoId;

            // Evento principal
            List<Evento__c> evs = [
                SELECT Id, Name, DataEvento__c, LocalizacaoEvento__c,
                       CategoriaPrincipal__c, ClassificacaoEtaria__c,
                       CapacidadeMaxima__c, Pricebook__c,
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
            out.dataEvento       = ev.DataEvento__c != null ? ev.DataEvento__c.format() : '';
            out.recinto          = (ev.Recinto__r != null ? ev.Recinto__r.Name + ', ' + ev.Recinto__r.Cidade__c : ev.LocalizacaoEvento__c);
            out.categoria        = ev.CategoriaPrincipal__c;
            out.classificacaoEtaria = ev.ClassificacaoEtaria__c;
            out.capacidadeMaxima = ev.CapacidadeMaxima__c != null ? ev.CapacidadeMaxima__c.intValue() : 0;

            // Preços por tipo
            if (ev.Pricebook__c != null) {
                for (PricebookEntry pbe : [
                    SELECT Product2.ProductCode, UnitPrice
                    FROM   PricebookEntry
                    WHERE  Pricebook2Id              = :ev.Pricebook__c
                    AND    Product2.ProductCode      IN ('BLT-Geral','BLT-VIP','BLT-CAMAROTE')
                    AND    IsActive                  = true
                ]) {
                    Decimal comIva = (pbe.UnitPrice * 1.23).setScale(2);
                    if      (pbe.Product2.ProductCode == 'BLT-Geral')     out.precoGeral    = comIva;
                    else if (pbe.Product2.ProductCode == 'BLT-VIP')       out.precoVIP      = comIva;
                    else if (pbe.Product2.ProductCode == 'BLT-CAMAROTE')  out.precoCamarote = comIva;
                }

                // Extras
                List<Map<String, Object>> extras = new List<Map<String, Object>>();
                for (PricebookEntry pbe : [
                    SELECT Product2.Name, Product2.ProductCode, UnitPrice
                    FROM   PricebookEntry
                    WHERE  Pricebook2Id         = :ev.Pricebook__c
                    AND    IsActive             = true
                    AND    Product2.ProductCode NOT IN ('BLT-Geral','BLT-VIP','BLT-CAMAROTE')
                ]) {
                    extras.add(new Map<String, Object>{
                        'nome'  => pbe.Product2.Name,
                        'code'  => pbe.Product2.ProductCode,
                        'preco' => (pbe.UnitPrice * 1.23).setScale(2)
                    });
                }
                out.extrasJson = JSON.serialize(extras);
            }

            // Lugares vendidos
            AggregateResult[] ar = [
                SELECT COUNT(Id) qtd FROM Bilhete__c
                WHERE  Evento__c         = :evId
                AND    EstadoBilhete__c  = 'Vendido'
            ];
            out.lugaresVendidos   = ar.isEmpty() ? 0 : (Integer) ar[0].get('qtd');
            out.lugaresDisponiveis = out.capacidadeMaxima - out.lugaresVendidos;

            // Mensagem para o chat
            String msg = '🎟️ *' + out.nomeEvento + '*\n\n';
            msg += '📅 ' + out.dataEvento + '\n';
            msg += '📍 ' + out.recinto    + '\n';
            msg += '🔞 Classificação: '   + (out.classificacaoEtaria ?? 'Livre') + '\n\n';
            msg += '💶 *Preços (c/ IVA):*\n';
            if (out.precoGeral    != null) msg += '   🎫 Geral: '    + out.precoGeral    + '€\n';
            if (out.precoVIP      != null) msg += '   ⭐ VIP: '      + out.precoVIP      + '€\n';
            if (out.precoCamarote != null) msg += '   🏆 Camarote: ' + out.precoCamarote + '€\n';
            msg += '\n🪑 Lugares disponíveis: ' + out.lugaresDisponiveis + ' / ' + out.capacidadeMaxima;

            if (out.lugaresDisponiveis <= 0) {
                msg += '\n⚠️ *Este evento está esgotado.*';
            } else if (out.lugaresDisponiveis < 20) {
                msg += '\n🔥 *Poucos lugares restantes!*';
            }

            out.mensagemChat = msg;

        } catch (Exception e) {
            out.erroMsg      = 'Erro: ' + e.getMessage();
            out.mensagemChat = 'Não consegui obter os detalhes do evento. Tenta novamente.';
        }
        return new List<Output>{ out };
    }
}