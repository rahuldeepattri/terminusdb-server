:- module(turtle_utils,[
              graph_to_turtle/3,
              update_turtle_graph/4,
              dump_turtle_graph/4
          ]).

/** <module> Turtle utilities
 *
 * Utilities for manipulating, inputing and outputing turtle
 *
 * * * * * * * * * * * * * COPYRIGHT NOTICE  * * * * * * * * * * * * * * *
 *                                                                       *
 *  This file is part of TerminusDB.                                     *
 *                                                                       *
 *  TerminusDB is free software: you can redistribute it and/or modify   *
 *  it under the terms of the GNU General Public License as published by *
 *  the Free Software Foundation, under version 3 of the License.        *
 *                                                                       *
 *                                                                       *
 *  TerminusDB is distributed in the hope that it will be useful,        *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of       *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        *
 *  GNU General Public License for more details.                         *
 *                                                                       *
 *  You should have received a copy of the GNU General Public License    *
 *  along with TerminusDB.  If not, see <https://www.gnu.org/licenses/>. *
 *                                                                       *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

:- use_module(core(util)).
:- use_module(triplestore).
:- use_module(literals).
:- use_module(core(query)).
:- use_module(core(transaction)).

:- use_module(library(semweb/turtle)).

/*
 * update_turtle_graph(+DB,+Type,+Name,+TTL) is det.
 *
 */
update_turtle_graph(Database,Type,Name,TTL) :-
    (   member(Transaction,Database.transaction_objects),
        Filter = type_name_filter{ type : Type, names : [Name]},
        filter_transaction_object_read_write_objects(Filter, Transaction, [Graph])
    ->  true
    ;   format(atom(M), 'No such schema named ~s', [Name]),
        throw(error(schema_error(_{'@type' : "vio:SchemaDoesNotExist",
                                   'vio:message' : M})))),

    coerce_literal_string(TTL, TTLS),
    setup_call_cleanup(
        open_string(TTLS, TTLStream),
        turtle_transaction(Database, Graph, TTLStream,_),
        close(TTLStream)
    ).

/*
 * dump_turtle_graph(+DB,+Type,+Name,-String) is semidet.
 *
 */
dump_turtle_graph(Database,Type,Name,String) :-
    Graph_Filter = type_name_filter{ type: Type, names : [Name]},
    [Transaction_Object] = Database.transaction_objects,
    filter_transaction_object_read_write_objects(Graph_Filter, Transaction_Object, [Graph]),

    with_output_to(
        string(String),
        (   current_output(Stream),
            dict_pairs(Database.prefixes, _, Pairs),
            graph_to_turtle(Pairs, Graph, Stream)
        )
    ).

/**
 * graph_to_turtle(+Prefixes,+G,+Output_Stream) is det.
 *
 * Create a ttl representation of the graph G in the
 * database named N.
 */
graph_to_turtle(Prefixes,G,Out_Stream) :-
    (   var(G.read)
    ->  true
    ;   layer_to_turtle(G.read,Prefixes,Out_Stream)).

/**
 * turtle_triples(Layer,Graph,X,P,Y) is nondet.
 */
turtle_triples(Layer,X,P,Y,_) :-
    ground(Y),
    !,
    (   \+ (   atom(Y)
           ;   string(Y))
    ->  fixup_schema_literal(Y,YO)
    ;   Y = YO),
    xrdf_db(Layer,X,P,YO).
turtle_triples(Layer,X,P,Y,_) :-
    xrdf_db(Layer,X,P,YO),
    (   is_literal(YO)
    ->  fixup_schema_literal(Y,YO)
    ;   Y = YO).

/**
 * layer_to_turtle(Layer,Prefixes,Out_Stream) is det.
 *
 * Write out triples from Layer to Out_Stream, using turtle_triples/5
 * as the generator, with prefixes, Prefixes.
 */
layer_to_turtle(Layer,Prefixes,Out_Stream) :-
   rdf_save_canonical_turtle(
        Out_Stream,
        [prefixes(Prefixes),
         encoding(utf8),
         expand(turtle_triples(Layer)),
         inline_bnodes(true),
         group(true),
         indent(2),
         silent(true)]
    ).
