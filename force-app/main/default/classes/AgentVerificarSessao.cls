public with sharing class AgentVerificarSessao {

    public class Input {
        @InvocableVariable(label='accountId' required=false)
        public String accountId;
    }

    public class Output {
        @InvocableVariable(label='Autenticado')
        public Boolean isLoggedIn;

        @InvocableVariable(label='Primeiro Nome')
        public String firstName;

        @InvocableVariable(label='Nome Completo')
        public String fullName;

        @InvocableVariable(label='Email')
        public String email;

        @InvocableVariable(label='Cidade')
        public String cidade;

        @InvocableVariable(label='Preferencias')
        public String categoriasPreferidas;

        @InvocableVariable(label='Erro')
        public String erroMsg;

        @InvocableVariable(label='accountId')
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

            Id targetAccId;
            try {
                targetAccId = (Id) inp.accountId;
            } catch (Exception e) {
                out.erroMsg = 'ID de sessao invalido.';
                return new List<Output>{ out };
            }

            List<Account> accs = [
                SELECT Id, FirstName, LastName, PersonEmail, BillingCity, CategoriaFavorita__c
                FROM Account
                WHERE Id = :targetAccId
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