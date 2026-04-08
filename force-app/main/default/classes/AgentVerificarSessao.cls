public with sharing class AgentVerificarSessao {

    public class Input {
        @InvocableVariable(label='Account ID')
        public String accountId;
    }

    public class Output {
        @InvocableVariable(label='Está autenticado?')
        public Boolean isLoggedIn;

        @InvocableVariable(label='Primeiro nome')
        public String firstName;

        @InvocableVariable(label='Nome completo')
        public String fullName;

        @InvocableVariable(label='Email')
        public String email;

        @InvocableVariable(label='Cidade')
        public String cidade;

        @InvocableVariable(label='Categorias preferidas')
        public String categoriasPreferidas;

        @InvocableVariable(label='Mensagem de erro')
        public String erroMsg;

        @InvocableVariable(label='Account ID')
        public String accountId;
    }

    @InvocableMethod(
        label='Agente - Verificar Sessao do Utilizador'
        description='Verifica se o accountId corresponde a um utilizador valido e retorna o seu perfil.'
        category='GLOBAZ Tickets'
    )
    public static List<Output> verificarSessao(List<Input> inputs) {
        Output out = new Output();
        out.isLoggedIn = false;

        try {
            if (inputs == null || inputs.isEmpty()) {
                out.erroMsg = 'Sem dados de entrada.';
                return new List<Output>{ out };
            }

            Input inp = inputs[0];

            if (String.isBlank(inp.accountId)) {
                out.erroMsg = 'Sem sessao ativa.';
                return new List<Output>{ out };
            }

            Id accId;
            try {
                accId = (Id) inp.accountId;
            } catch (Exception e) {
                out.erroMsg = 'ID de sessao invalido.';
                return new List<Output>{ out };
            }

            List<Account> accs = [
                SELECT Id, FirstName, LastName, PersonEmail, BillingCity, CategoriaFavorita__c
                FROM Account
                WHERE Id = :accId
                AND IsPersonAccount = true
                AND Valido__c = true
                LIMIT 1
            ];

            if (accs.isEmpty()) {
                out.erroMsg = 'Conta nao encontrada ou invalida.';
                return new List<Output>{ out };
            }

            Account acc = accs[0];
            out.isLoggedIn = true;
            out.firstName = acc.FirstName;
            out.fullName = ((acc.FirstName == null ? '' : acc.FirstName) + ' ' + (acc.LastName == null ? '' : acc.LastName)).trim();
            out.email = acc.PersonEmail;
            out.cidade = acc.BillingCity;
            out.categoriasPreferidas = (String)acc.get('CategoriaFavorita__c');
            out.accountId = String.valueOf(acc.Id);

        } catch (Exception e) {
            out.isLoggedIn = false;
            out.erroMsg = 'Erro: ' + e.getMessage();
        }

        return new List<Output>{ out };
    }
}